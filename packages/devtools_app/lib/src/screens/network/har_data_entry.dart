// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import '../../shared/http/http_request_data.dart';
import '../../shared/primitives/utils.dart';
import 'constants.dart';

class HarDataEntry {
  HarDataEntry(this.request);

  /// Creates an instance of [HarDataEntry] from a JSON object.
  ///
  /// This factory constructor expects the [json] parameter to be a Map
  /// representing a single HAR entry.
  factory HarDataEntry.fromJson(Map<String, Object?> json) {
    _convertHeaders(json);

    final modifiedRequestData =
        _remapCustomFieldKeys(json) as Map<String, dynamic>;

    // Retrieving url, method from requestData
    modifiedRequestData['uri'] =
        (modifiedRequestData['request'] as Map<String, Object?>)['url'];
    modifiedRequestData['method'] =
        (modifiedRequestData['request'] as Map<String, Object?>)['method'];

    // Adding missing keys which are mandatory for parsing
    (modifiedRequestData['response'] as Map<String, Object?>)['redirects'] = [];
    Object? requestPostData;
    Object? responseContent;
    if (modifiedRequestData['response'] != null &&
        (modifiedRequestData['response'] as Map<String, Object?>)['content'] !=
            null) {
      responseContent =
          (modifiedRequestData['response'] as Map<String, Object?>)['content'];
    }

    if (modifiedRequestData['request'] != null &&
        (modifiedRequestData['request'] as Map<String, Object?>)['postData'] !=
            null) {
      requestPostData =
          (modifiedRequestData['response'] as Map<String, Object?>)['content'];
    }

    return HarDataEntry(
      DartIOHttpRequestData.fromJson(
        modifiedRequestData,
        requestPostData as Map<String, Object?>,
        responseContent as Map<String, Object?>,
      ),
    );
  }

  final DartIOHttpRequestData request;

  /// Converts the instance to a JSON object.
  ///
  /// This method returns a Map representing a single HAR entry, suitable for
  /// serialization.
  static Map<String, Object?> toJson(DartIOHttpRequestData e) {
    // Implement the logic to convert DartIOHttpRequestData to HAR entry format
    final requestCookies = e.requestCookies.map((cookie) {
      return <String, Object?>{
        NetworkEventKeys.name.name: cookie.name,
        NetworkEventKeys.value.name: cookie.value,
        'path': cookie.path,
        'domain': cookie.domain,
        'expires': cookie.expires?.toUtc().toIso8601String(),
        'httpOnly': cookie.httpOnly,
        'secure': cookie.secure,
      };
    }).toList();

    final requestHeaders = e.requestHeaders?.entries.map((header) {
      var value = header.value;
      if (value is List) {
        value = value.first;
      }
      return <String, Object?>{
        NetworkEventKeys.name.name: header.key,
        NetworkEventKeys.value.name: value,
      };
    }).toList();

    final queryString = Uri.parse(e.uri).queryParameters.entries.map((param) {
      return <String, Object?>{
        NetworkEventKeys.name.name: param.key,
        NetworkEventKeys.value.name: param.value,
      };
    }).toList();

    final responseCookies = e.responseCookies.map((cookie) {
      return <String, Object?>{
        NetworkEventKeys.name.name: cookie.name,
        NetworkEventKeys.value.name: cookie.value,
        'path': cookie.path,
        'domain': cookie.domain,
        'expires': cookie.expires?.toUtc().toIso8601String(),
        'httpOnly': cookie.httpOnly,
        'secure': cookie.secure,
      };
    }).toList();

    final responseHeaders = e.responseHeaders?.entries.map((header) {
      var value = header.value;
      if (value is List) {
        value = value.first;
      }
      return <String, Object?>{
        NetworkEventKeys.name.name: header.key,
        NetworkEventKeys.value.name: value,
      };
    }).toList();

    return <String, Object?>{
      NetworkEventKeys.startedDateTime.name:
          e.startTimestamp.toUtc().toIso8601String(),
      NetworkEventKeys.time.name: e.duration?.inMilliseconds,
      // Request
      NetworkEventKeys.request.name: <String, Object?>{
        NetworkEventKeys.method.name: e.method.toUpperCase(),
        NetworkEventKeys.url.name: e.uri.toString(),
        NetworkEventKeys.httpVersion.name: NetworkEventDefaults.httpVersion,
        NetworkEventKeys.cookies.name: requestCookies,
        NetworkEventKeys.headers.name: requestHeaders,
        NetworkEventKeys.queryString.name: queryString,
        NetworkEventKeys.postData.name: <String, Object?>{
          NetworkEventKeys.mimeType.name: e.contentType,
          NetworkEventKeys.text.name: e.requestBody,
        },
        NetworkEventKeys.headersSize.name:
            _calculateHeadersSize(e.requestHeaders),
        NetworkEventKeys.bodySize.name: _calculateBodySize(e.requestBody),
      },
      // Response
      NetworkEventKeys.response.name: <String, Object?>{
        NetworkEventKeys.status.name: e.status,
        NetworkEventKeys.statusText.name: '',
        NetworkEventKeys.httpVersion.name:
            NetworkEventDefaults.responseHttpVersion,
        NetworkEventKeys.cookies.name: responseCookies,
        NetworkEventKeys.headers.name: responseHeaders,
        NetworkEventKeys.content.name: <String, Object?>{
          NetworkEventKeys.size.name: e.responseBody?.length,
          NetworkEventKeys.mimeType.name: e.type,
          NetworkEventKeys.text.name: e.responseBody,
        },
        NetworkEventKeys.redirectURL.name: '',
        NetworkEventKeys.headersSize.name:
            _calculateHeadersSize(e.responseHeaders),
        NetworkEventKeys.bodySize.name: _calculateBodySize(e.responseBody),
      },
      // Cache
      NetworkEventKeys.cache.name: <String, Object?>{},
      NetworkEventKeys.timings.name: <String, Object?>{
        NetworkEventKeys.blocked.name: NetworkEventDefaults.blocked,
        NetworkEventKeys.dns.name: NetworkEventDefaults.dns,
        NetworkEventKeys.connect.name: NetworkEventDefaults.connect,
        NetworkEventKeys.send.name: NetworkEventDefaults.send,
        NetworkEventKeys.wait.name: e.duration?.inMilliseconds ?? 0,
        NetworkEventKeys.receive.name: NetworkEventDefaults.receive,
        NetworkEventKeys.ssl.name: NetworkEventDefaults.ssl,
      },
      NetworkEventKeys.connection.name: e.hashCode.toString(),
      NetworkEventKeys.comment.name: '',

      // Custom fields
      // har spec requires underscore to be added for custom fields, hence removing them
      NetworkEventCustomFieldKeys.isolateId: '',
      NetworkEventCustomFieldKeys.id: e.id,
      NetworkEventCustomFieldKeys.startTime:
          e.startTimestamp.microsecondsSinceEpoch,
      NetworkEventCustomFieldKeys.events: [],
    };
  }

  /// Converts the HAR data entry back to [DartIOHttpRequestData].
  DartIOHttpRequestData toDartIOHttpRequest() {
    return request;
  }

  static Map<String, dynamic> _convertHeadersListToMap(
    List<dynamic> serializedHeaders,
  ) {
    final transformedHeaders = <String, dynamic>{};

    for (final header in serializedHeaders) {
      if (header is Map<String, dynamic>) {
        final key = header[NetworkEventKeys.name.name] as String?;
        final value = header[NetworkEventKeys.value.name];

        if (key != null) {
          if (transformedHeaders.containsKey(key)) {
            if (transformedHeaders[key] is List) {
              (transformedHeaders[key] as List).add(value);
            } else {
              transformedHeaders[key] = [transformedHeaders[key], value];
            }
          } else {
            transformedHeaders[key] = value;
          }
        }
      }
    }

    return transformedHeaders;
  }

  // Convert list of headers to map
  static void _convertHeaders(Map<String, dynamic> requestData) {
    // Request Headers
    if (requestData['request'] != null &&
        (requestData['request'] as Map<String, Object?>)['headers'] != null) {
      if ((requestData['request'] as Map<String, Object?>)['headers'] is List) {
        (requestData['request'] as Map<String, Object?>)['headers'] =
            _convertHeadersListToMap(
          ((requestData['request'] as Map<String, Object?>)['headers'])
              as List<dynamic>,
        );
      }
    }

    // Response Headers
    if (requestData['response'] != null &&
        (requestData['response'] as Map<String, Object?>)['headers'] != null) {
      if ((requestData['response'] as Map<String, Object?>)['headers']
          is List) {
        (requestData['response'] as Map<String, Object?>)['headers'] =
            _convertHeadersListToMap(
          ((requestData['response'] as Map<String, Object?>)['headers'])
              as List<dynamic>,
        );
      }
    }
  }

  // Removing underscores from custom fields
  static Map<String, Object?> _remapCustomFieldKeys(
    Map<String, Object?> originalMap,
  ) {
    final replacementMap = {
      NetworkEventCustomFieldKeys.isolateId:
          NetworkEventCustomFieldRemappedKeys.isolateId.name,
      NetworkEventCustomFieldKeys.id:
          NetworkEventCustomFieldRemappedKeys.id.name,
      NetworkEventCustomFieldKeys.startTime:
          NetworkEventCustomFieldRemappedKeys.startTime.name,
      NetworkEventCustomFieldKeys.events:
          NetworkEventCustomFieldRemappedKeys.events.name,
    };

    final convertedMap = <String, dynamic>{};

    originalMap.forEach((key, value) {
      if (replacementMap.containsKey(key)) {
        convertedMap[replacementMap[key]!] = value;
      } else {
        convertedMap[key] = value;
      }
    });

    return convertedMap;
  }
}

int _calculateHeadersSize(Map<String, dynamic>? headers) {
  if (headers == null) return -1;

  // Combine headers into a single string with CRLF endings
  String headersString = headers.entries.map((entry) {
    final key = entry.key;
    var value = entry.value;
    // If the value is a List, join it with a comma
    if (value is List<String>) {
      value = value.join(', ');
    }
    return '$key: $value\r\n';
  }).join();

  // Add final CRLF to indicate end of headers
  headersString += '\r\n';

  // Calculate the byte length of the headers string
  return utf8.encode(headersString).length;
}

int _calculateBodySize(String? requestBody) {
  if (requestBody.isNullOrEmpty) {
    return 0;
  }
  return utf8.encode(requestBody!).length;
}