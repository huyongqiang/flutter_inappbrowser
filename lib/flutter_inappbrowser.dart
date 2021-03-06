/*
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 *
*/

import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';

typedef Future<dynamic> ListenerCallback(MethodCall call);
typedef Future<void> JavaScriptHandlerCallback(List<dynamic> arguments);

var _uuidGenerator = new Uuid();

///
enum ConsoleMessageLevel {
  DEBUG, ERROR, LOG, TIP, WARNING
}

///Public class representing a resource request of the [InAppBrowser] WebView.
///It is used by the method [InAppBrowser.onLoadResource()].
class WebResourceRequest {

  String url;
  Map<String, String> headers;
  String method;

  WebResourceRequest(this.url, this.headers, this.method);

}

///Public class representing a resource response of the [InAppBrowser] WebView.
///It is used by the method [InAppBrowser.onLoadResource()].
class WebResourceResponse {

  String url;
  Map<String, String> headers;
  int statusCode;
  int startTime;
  int duration;
  Uint8List data;

  WebResourceResponse(this.url, this.headers, this.statusCode, this.startTime, this.duration, this.data);

}

///Public class representing a JavaScript console message from WebCore.
///This could be a issued by a call to one of the console logging functions (e.g. console.log('...')) or a JavaScript error on the page.
///
///To receive notifications of these messages, override the [InAppBrowser.onConsoleMessage()] function.
class ConsoleMessage {

  String sourceURL = "";
  int lineNumber = 1;
  String message = "";
  ConsoleMessageLevel messageLevel = ConsoleMessageLevel.LOG;

  ConsoleMessage(this.sourceURL, this.lineNumber, this.message, this.messageLevel);
}

class _ChannelManager {
  static const MethodChannel channel = const MethodChannel('com.pichillilorenzo/flutter_inappbrowser');
  static final initialized = false;
  static final listeners = HashMap<String, ListenerCallback>();

  static Future<dynamic> _handleMethod(MethodCall call) async {
    String uuid = call.arguments["uuid"];
    return await listeners[uuid](call);
  }

  static void addListener(String key, ListenerCallback callback) {
    if (!initialized)
      init();
    listeners.putIfAbsent(key, () => callback);
  }

  static void init () {
    channel.setMethodCallHandler(_handleMethod);
  }
}

///InAppBrowser class. [webViewController] can be used to access the [InAppWebView] API.
///
///This class uses the native WebView of the platform.
class InAppBrowser {

  String uuid;
  Map<String, List<JavaScriptHandlerCallback>> javaScriptHandlersMap = HashMap<String, List<JavaScriptHandlerCallback>>();
  bool _isOpened = false;
  /// WebView Controller that can be used to access the [InAppWebView] API.
  InAppWebViewController webViewController;

  ///
  InAppBrowser () {
    uuid = _uuidGenerator.v4();
    _ChannelManager.addListener(uuid, _handleMethod);
    _isOpened = false;
    webViewController = new InAppWebViewController.fromInAppBrowser(uuid, _ChannelManager.channel, this);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch(call.method) {
      case "onExit":
        this._isOpened = false;
        onExit();
        break;
      default:
        return webViewController._handleMethod(call);
    }
  }

  ///Opens an [url] in a new [InAppBrowser] instance.
  ///
  ///- [url]: The [url] to load. Call [encodeUriComponent()] on this if the [url] contains Unicode characters. The default value is `about:blank`.
  ///
  ///- [headers]: The additional headers to be used in the HTTP request for this URL, specified as a map from name to value.
  ///
  ///- [options]: Options for the [InAppBrowser].
  ///
  ///  - All platforms support:
  ///    - __useShouldOverrideUrlLoading__: Set to `true` to be able to listen at the [shouldOverrideUrlLoading()] event. The default value is `false`.
  ///    - __useOnLoadResource__: Set to `true` to be able to listen at the [onLoadResource()] event. The default value is `false`.
  ///    - __clearCache__: Set to `true` to have all the browser's cache cleared before the new window is opened. The default value is `false`.
  ///    - __userAgent__: Set the custom WebView's user-agent.
  ///    - __javaScriptEnabled__: Set to `true` to enable JavaScript. The default value is `true`.
  ///    - __javaScriptCanOpenWindowsAutomatically__: Set to `true` to allow JavaScript open windows without user interaction. The default value is `false`.
  ///    - __hidden__: Set to `true` to create the browser and load the page, but not show it. The `onLoadStop` event fires when loading is complete. Omit or set to `false` (default) to have the browser open and load normally.
  ///    - __toolbarTop__: Set to `false` to hide the toolbar at the top of the WebView. The default value is `true`.
  ///    - __toolbarTopBackgroundColor__: Set the custom background color of the toolbar at the top.
  ///    - __hideUrlBar__: Set to `true` to hide the url bar on the toolbar at the top. The default value is `false`.
  ///    - __mediaPlaybackRequiresUserGesture__: Set to `true` to prevent HTML5 audio or video from autoplaying. The default value is `true`.
  ///
  ///  - **Android** supports these additional options:
  ///
  ///    - __hideTitleBar__: Set to `true` if you want the title should be displayed. The default value is `false`.
  ///    - __closeOnCannotGoBack__: Set to `false` to not close the InAppBrowser when the user click on the back button and the WebView cannot go back to the history. The default value is `true`.
  ///    - __clearSessionCache__: Set to `true` to have the session cookie cache cleared before the new window is opened.
  ///    - __builtInZoomControls__: Set to `true` if the WebView should use its built-in zoom mechanisms. The default value is `false`.
  ///    - __supportZoom__: Set to `false` if the WebView should not support zooming using its on-screen zoom controls and gestures. The default value is `true`.
  ///    - __databaseEnabled__: Set to `true` if you want the database storage API is enabled. The default value is `false`.
  ///    - __domStorageEnabled__: Set to `true` if you want the DOM storage API is enabled. The default value is `false`.
  ///    - __useWideViewPort__: Set to `true` if the WebView should enable support for the "viewport" HTML meta tag or should use a wide viewport. When the value of the setting is false, the layout width is always set to the width of the WebView control in device-independent (CSS) pixels. When the value is true and the page contains the viewport meta tag, the value of the width specified in the tag is used. If the page does not contain the tag or does not provide a width, then a wide viewport will be used. The default value is `true`.
  ///    - __safeBrowsingEnabled__: Set to `true` if you want the Safe Browsing is enabled. Safe Browsing allows WebView to protect against malware and phishing attacks by verifying the links. The default value is `true`.
  ///    - __progressBar__: Set to `false` to hide the progress bar at the bottom of the toolbar at the top. The default value is `true`.
  ///
  ///  - **iOS** supports these additional options:
  ///
  ///    - __disallowOverScroll__: Set to `true` to disable the bouncing of the WebView when the scrolling has reached an edge of the content. The default value is `false`.
  ///    - __toolbarBottom__: Set to `false` to hide the toolbar at the bottom of the WebView. The default value is `true`.
  ///    - __toolbarBottomBackgroundColor__: Set the custom background color of the toolbar at the bottom.
  ///    - __toolbarBottomTranslucent__: Set to `true` to set the toolbar at the bottom translucent. The default value is `true`.
  ///    - __closeButtonCaption__: Set the custom text for the close button.
  ///    - __closeButtonColor__: Set the custom color for the close button.
  ///    - __presentationStyle__: Set the custom modal presentation style when presenting the WebView. The default value is `0 //fullscreen`. See [UIModalPresentationStyle](https://developer.apple.com/documentation/uikit/uimodalpresentationstyle) for all the available styles.
  ///    - __transitionStyle__: Set to the custom transition style when presenting the WebView. The default value is `0 //crossDissolve`. See [UIModalTransitionStyle](https://developer.apple.com/documentation/uikit/uimodaltransitionStyle) for all the available styles.
  ///    - __enableViewportScale__: Set to `true` to allow a viewport meta tag to either disable or restrict the range of user scaling. The default value is `false`.
  ///    - __suppressesIncrementalRendering__: Set to `true` if you want the WebView suppresses content rendering until it is fully loaded into memory.. The default value is `false`.
  ///    - __allowsAirPlayForMediaPlayback__: Set to `true` to allow AirPlay. The default value is `true`.
  ///    - __allowsBackForwardNavigationGestures__: Set to `true` to allow the horizontal swipe gestures trigger back-forward list navigations. The default value is `true`.
  ///    - __allowsLinkPreview__: Set to `true` to allow that pressing on a link displays a preview of the destination for the link. The default value is `true`.
  ///    - __ignoresViewportScaleLimits__: Set to `true` if you want that the WebView should always allow scaling of the webpage, regardless of the author's intent. The ignoresViewportScaleLimits property overrides the `user-scalable` HTML property in a webpage. The default value is `false`.
  ///    - __allowsInlineMediaPlayback__: Set to `true` to allow HTML5 media playback to appear inline within the screen layout, using browser-supplied controls rather than native controls. For this to work, add the `webkit-playsinline` attribute to any `<video>` elements. The default value is `false`.
  ///    - __allowsPictureInPictureMediaPlayback__: Set to `true` to allow HTML5 videos play picture-in-picture. The default value is `true`.
  ///    - __spinner__: Set to `false` to hide the spinner when the WebView is loading a page. The default value is `true`.
  Future<void> open({String url = "about:blank", Map<String, String> headers = const {}, Map<String, dynamic> options = const {}}) async {
    assert(url != null && url.isNotEmpty);
    this._throwIsAlreadyOpened(message: 'Cannot open $url!');
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('uuid', () => uuid);
    args.putIfAbsent('url', () => url);
    args.putIfAbsent('headers', () => headers);
    args.putIfAbsent('options', () => options);
    args.putIfAbsent('openWithSystemBrowser', () => false);
    args.putIfAbsent('isLocalFile', () => false);
    args.putIfAbsent('useChromeSafariBrowser', () => false);
    await _ChannelManager.channel.invokeMethod('open', args);
    this._isOpened = true;
  }

  ///Opens the giver [assetFilePath] file in a new [InAppBrowser] instance. The other arguments are the same of [InAppBrowser.open()].
  ///
  ///To be able to load your local files (assets, js, css, etc.), you need to add them in the `assets` section of the `pubspec.yaml` file, otherwise they cannot be found!
  ///
  ///Example of a `pubspec.yaml` file:
  ///```yaml
  ///...
  ///
  ///# The following section is specific to Flutter.
  ///flutter:
  ///
  ///  # The following line ensures that the Material Icons font is
  ///  # included with your application, so that you can use the icons in
  ///  # the material Icons class.
  ///  uses-material-design: true
  ///
  ///  assets:
  ///    - assets/index.html
  ///    - assets/css/
  ///    - assets/images/
  ///
  ///...
  ///```
  ///Example of a `main.dart` file:
  ///```dart
  ///...
  ///inAppBrowser.openFile("assets/index.html");
  ///...
  ///```
  Future<void> openFile(String assetFilePath, {Map<String, String> headers = const {}, Map<String, dynamic> options = const {}}) async {
    assert(assetFilePath != null && assetFilePath.isNotEmpty);
    this._throwIsAlreadyOpened(message: 'Cannot open $assetFilePath!');
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('uuid', () => uuid);
    args.putIfAbsent('url', () => assetFilePath);
    args.putIfAbsent('headers', () => headers);
    args.putIfAbsent('options', () => options);
    args.putIfAbsent('openWithSystemBrowser', () => false);
    args.putIfAbsent('isLocalFile', () => true);
    args.putIfAbsent('useChromeSafariBrowser', () => false);
    await _ChannelManager.channel.invokeMethod('open', args);
    this._isOpened = true;
  }

  ///This is a static method that opens an [url] in the system browser. You wont be able to use the [InAppBrowser] methods here!
  static Future<void> openWithSystemBrowser(String url) async {
    assert(url != null && url.isNotEmpty);
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('uuid', () => "");
    args.putIfAbsent('url', () => url);
    args.putIfAbsent('headers', () => {});
    args.putIfAbsent('isLocalFile', () => false);
    args.putIfAbsent('openWithSystemBrowser', () => true);
    args.putIfAbsent('useChromeSafariBrowser', () => false);
    return await _ChannelManager.channel.invokeMethod('open', args);
  }

  ///Displays an [InAppBrowser] window that was opened hidden. Calling this has no effect if the [InAppBrowser] was already visible.
  Future<void> show() async {
    this._throwIsNotOpened();
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('uuid', () => uuid);
    await _ChannelManager.channel.invokeMethod('show', args);
  }

  ///Hides the [InAppBrowser] window. Calling this has no effect if the [InAppBrowser] was already hidden.
  Future<void> hide() async {
    this._throwIsNotOpened();
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('uuid', () => uuid);
    await _ChannelManager.channel.invokeMethod('hide', args);
  }

  ///Closes the [InAppBrowser] window.
  Future<void> close() async {
    this._throwIsNotOpened();
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('uuid', () => uuid);
    await _ChannelManager.channel.invokeMethod('close', args);
  }

  ///Check if the Web View of the [InAppBrowser] instance is hidden.
  Future<bool> isHidden() async {
    this._throwIsNotOpened();
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('uuid', () => uuid);
    return await _ChannelManager.channel.invokeMethod('isHidden', args);
  }

  ///Sets the [InAppBrowser] options with the new [options] and evaluates them.
  Future<void> setOptions(Map<String, dynamic> options) async {
    this._throwIsNotOpened();
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('uuid', () => uuid);
    args.putIfAbsent('options', () => options);
    args.putIfAbsent('optionsType', () => "InAppBrowserOptions");
    await _ChannelManager.channel.invokeMethod('setOptions', args);
  }

  ///Gets the current [InAppBrowser] options. Returns `null` if the options are not setted yet.
  Future<Map<String, dynamic>> getOptions() async {
    this._throwIsNotOpened();
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('uuid', () => uuid);
    args.putIfAbsent('optionsType', () => "InAppBrowserOptions");
    Map<dynamic, dynamic> options = await _ChannelManager.channel.invokeMethod('getOptions', args);
    options = options.cast<String, dynamic>();
    return options;
  }

  ///Returns `true` if the [InAppBrowser] instance is opened, otherwise `false`.
  bool isOpened() {
    return this._isOpened;
  }

  ///Event fires when the [InAppBrowser] starts to load an [url].
  void onLoadStart(String url) {

  }

  ///Event fires when the [InAppBrowser] finishes loading an [url].
  void onLoadStop(String url) {

  }

  ///Event fires when the [InAppBrowser] encounters an error loading an [url].
  void onLoadError(String url, int code, String message) {

  }

  ///Event fires when the current [progress] (range 0-100) of loading a page is changed.
  void onProgressChanged(int progress) {

  }

  ///Event fires when the [InAppBrowser] window is closed.
  void onExit() {

  }

  ///Event fires when the [InAppBrowser] webview receives a [ConsoleMessage].
  void onConsoleMessage(ConsoleMessage consoleMessage) {

  }

  ///Give the host application a chance to take control when a URL is about to be loaded in the current WebView.
  ///
  ///**NOTE**: In order to be able to listen this event, you need to set `useShouldOverrideUrlLoading` option to `true`.
  void shouldOverrideUrlLoading(String url) {

  }

  ///Event fires when the [InAppBrowser] webview loads a resource.
  ///
  ///**NOTE**: In order to be able to listen this event, you need to set `useOnLoadResource` option to `true`.
  ///
  ///**NOTE only for iOS**: In some cases, the [response.data] of a [response] with `text/assets` encoding could be empty.
  void onLoadResource(WebResourceResponse response, WebResourceRequest request) {

  }

  void _throwIsAlreadyOpened({String message = ''}) {
    if (this.isOpened()) {
      throw Exception(['Error: ${ (message.isEmpty) ? '' : message + ' '}The browser is already opened.']);
    }
  }

  void _throwIsNotOpened({String message = ''}) {
    if (!this.isOpened()) {
      throw Exception(['Error: ${ (message.isEmpty) ? '' : message + ' '}The browser is not opened.']);
    }
  }
}

///ChromeSafariBrowser class.
///
///This class uses native [Chrome Custom Tabs](https://developer.android.com/reference/android/support/customtabs/package-summary) on Android
///and [SFSafariViewController](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller) on iOS.
///
///[browserFallback] represents the [InAppBrowser] instance fallback in case [Chrome Custom Tabs]/[SFSafariViewController] is not available.
class ChromeSafariBrowser {
  String uuid;
  InAppBrowser browserFallback;
  bool _isOpened = false;

  ///Initialize the [ChromeSafariBrowser] instance with an [InAppBrowser] fallback instance or `null`.
  ChromeSafariBrowser (bf) {
    uuid = _uuidGenerator.v4();
    browserFallback = bf;
    _ChannelManager.addListener(uuid, _handleMethod);
    _isOpened = false;
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch(call.method) {
      case "onChromeSafariBrowserOpened":
        onOpened();
        break;
      case "onChromeSafariBrowserLoaded":
        onLoaded();
        break;
      case "onChromeSafariBrowserClosed":
        onClosed();
        this._isOpened = false;
        break;
      default:
        throw UnimplementedError("Unimplemented ${call.method} method");
    }
  }

  ///Opens an [url] in a new [ChromeSafariBrowser] instance.
  ///
  ///- [url]: The [url] to load. Call [encodeUriComponent()] on this if the [url] contains Unicode characters.
  ///
  ///- [options]: Options for the [ChromeSafariBrowser].
  ///
  ///- [headersFallback]: The additional header of the [InAppBrowser] instance fallback to be used in the HTTP request for this URL, specified as a map from name to value.
  ///
  ///- [optionsFallback]: Options used by the [InAppBrowser] instance fallback.
  ///
  ///**Android** supports these options:
  ///
  ///- __addShareButton__: Set to `false` if you don't want the default share button. The default value is `true`.
  ///- __showTitle__: Set to `false` if the title shouldn't be shown in the custom tab. The default value is `true`.
  ///- __toolbarBackgroundColor__: Set the custom background color of the toolbar.
  ///- __enableUrlBarHiding__: Set to `true` to enable the url bar to hide as the user scrolls down on the page. The default value is `false`.
  ///- __instantAppsEnabled__: Set to `true` to enable Instant Apps. The default value is `false`.
  ///
  ///**iOS** supports these options:
  ///
  ///- __entersReaderIfAvailable__: Set to `true` if Reader mode should be entered automatically when it is available for the webpage. The default value is `false`.
  ///- __barCollapsingEnabled__: Set to `true` to enable bar collapsing. The default value is `false`.
  ///- __dismissButtonStyle__: Set the custom style for the dismiss button. The default value is `0 //done`. See [SFSafariViewController.DismissButtonStyle](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller/dismissbuttonstyle) for all the available styles.
  ///- __preferredBarTintColor__: Set the custom background color of the navigation bar and the toolbar.
  ///- __preferredControlTintColor__: Set the custom color of the control buttons on the navigation bar and the toolbar.
  ///- __presentationStyle__: Set the custom modal presentation style when presenting the WebView. The default value is `0 //fullscreen`. See [UIModalPresentationStyle](https://developer.apple.com/documentation/uikit/uimodalpresentationstyle) for all the available styles.
  ///- __transitionStyle__: Set to the custom transition style when presenting the WebView. The default value is `0 //crossDissolve`. See [UIModalTransitionStyle](https://developer.apple.com/documentation/uikit/uimodaltransitionStyle) for all the available styles.
  Future<void> open(String url, {Map<String, dynamic> options = const {}, Map<String, String> headersFallback = const {}, Map<String, dynamic> optionsFallback = const {}}) async {
    assert(url != null && url.isNotEmpty);
    this._throwIsAlreadyOpened(message: 'Cannot open $url!');
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('uuid', () => uuid);
    args.putIfAbsent('uuidFallback', () => (browserFallback != null) ? browserFallback.uuid : '');
    args.putIfAbsent('url', () => url);
    args.putIfAbsent('headers', () => headersFallback);
    args.putIfAbsent('options', () => options);
    args.putIfAbsent('optionsFallback', () => optionsFallback);
    args.putIfAbsent('useChromeSafariBrowser', () => true);
    await _ChannelManager.channel.invokeMethod('open', args);
    this._isOpened = true;
  }

  ///Event fires when the [ChromeSafariBrowser] is opened.
  void onOpened() {

  }

  ///Event fires when the [ChromeSafariBrowser] is loaded.
  void onLoaded() {

  }

  ///Event fires when the [ChromeSafariBrowser] is closed.
  void onClosed() {

  }

  bool isOpened() {
    return this._isOpened;
  }

  void _throwIsAlreadyOpened({String message = ''}) {
    if (this.isOpened()) {
      throw Exception(['Error: ${ (message.isEmpty) ? '' : message + ' '}The browser is already opened.']);
    }
  }

  void _throwIsNotOpened({String message = ''}) {
    if (!this.isOpened()) {
      throw Exception(['Error: ${ (message.isEmpty) ? '' : message + ' '}The browser is not opened.']);
    }
  }
}

typedef void onWebViewCreatedCallback(InAppWebViewController controller);
typedef void onWebViewLoadStartCallback(InAppWebViewController controller, String url);
typedef void onWebViewLoadStopCallback(InAppWebViewController controller, String url);
typedef void onWebViewLoadErrorCallback(InAppWebViewController controller, String url, int code, String message);
typedef void onWebViewProgressChangedCallback(InAppWebViewController controller, int progress);
typedef void onWebViewConsoleMessageCallback(InAppWebViewController controller, ConsoleMessage consoleMessage);
typedef void shouldOverrideUrlLoadingCallback(InAppWebViewController controller, String url);
typedef void onWebViewLoadResourceCallback(InAppWebViewController controller, WebResourceResponse response, WebResourceRequest request);

///InAppWebView Widget class.
///
///Flutter Widget for adding an **inline native WebView** integrated in the flutter widget tree.
///
///All platforms support these options:
///  - __useShouldOverrideUrlLoading__: Set to `true` to be able to listen at the [InAppWebView.shouldOverrideUrlLoading()] event. The default value is `false`.
///  - __useOnLoadResource__: Set to `true` to be able to listen at the [InAppWebView.onLoadResource()] event. The default value is `false`.
///  - __clearCache__: Set to `true` to have all the browser's cache cleared before the new window is opened. The default value is `false`.
///  - __userAgent___: Set the custom WebView's user-agent.
///  - __javaScriptEnabled__: Set to `true` to enable JavaScript. The default value is `true`.
///  - __javaScriptCanOpenWindowsAutomatically__: Set to `true` to allow JavaScript open windows without user interaction. The default value is `false`.
///  - __mediaPlaybackRequiresUserGesture__: Set to `true` to prevent HTML5 audio or video from autoplaying. The default value is `true`.
///
///  **Android** supports these additional options:
///
///  - __clearSessionCache__: Set to `true` to have the session cookie cache cleared before the new window is opened.
///  - __builtInZoomControls__: Set to `true` if the WebView should use its built-in zoom mechanisms. The default value is `false`.
///  - __supportZoom__: Set to `false` if the WebView should not support zooming using its on-screen zoom controls and gestures. The default value is `true`.
///  - __databaseEnabled__: Set to `true` if you want the database storage API is enabled. The default value is `false`.
///  - __domStorageEnabled__: Set to `true` if you want the DOM storage API is enabled. The default value is `false`.
///  - __useWideViewPort__: Set to `true` if the WebView should enable support for the "viewport" HTML meta tag or should use a wide viewport. When the value of the setting is false, the layout width is always set to the width of the WebView control in device-independent (CSS) pixels. When the value is true and the page contains the viewport meta tag, the value of the width specified in the tag is used. If the page does not contain the tag or does not provide a width, then a wide viewport will be used. The default value is `true`.
///  - __safeBrowsingEnabled__: Set to `true` if you want the Safe Browsing is enabled. Safe Browsing allows WebView to protect against malware and phishing attacks by verifying the links. The default value is `true`.
///
///  **iOS** supports these additional options:
///
///  - __disallowOverScroll__: Set to `true` to disable the bouncing of the WebView when the scrolling has reached an edge of the content. The default value is `false`.
///  - __enableViewportScale__: Set to `true` to allow a viewport meta tag to either disable or restrict the range of user scaling. The default value is `false`.
///  - __suppressesIncrementalRendering__: Set to `true` if you want the WebView suppresses content rendering until it is fully loaded into memory.. The default value is `false`.
///  - __allowsAirPlayForMediaPlayback__: Set to `true` to allow AirPlay. The default value is `true`.
///  - __allowsBackForwardNavigationGestures__: Set to `true` to allow the horizontal swipe gestures trigger back-forward list navigations. The default value is `true`.
///  - __allowsLinkPreview__: Set to `true` to allow that pressing on a link displays a preview of the destination for the link. The default value is `true`.
///  - __ignoresViewportScaleLimits__: Set to `true` if you want that the WebView should always allow scaling of the webpage, regardless of the author's intent. The ignoresViewportScaleLimits property overrides the `user-scalable` HTML property in a webpage. The default value is `false`.
///  - __allowsInlineMediaPlayback__: Set to `true` to allow HTML5 media playback to appear inline within the screen layout, using browser-supplied controls rather than native controls. For this to work, add the `webkit-playsinline` attribute to any `<video>` elements. The default value is `false`.
///  - __allowsPictureInPictureMediaPlayback__: Set to `true` to allow HTML5 videos play picture-in-picture. The default value is `true`.
class InAppWebView extends StatefulWidget {

  ///Event fires when the [InAppWebView] is created.
  final onWebViewCreatedCallback onWebViewCreated;

  ///Event fires when the [InAppWebView] starts to load an [url].
  final onWebViewLoadStartCallback onLoadStart;

  ///Event fires when the [InAppWebView] finishes loading an [url].
  final onWebViewLoadStopCallback onLoadStop;

  ///Event fires when the [InAppWebView] encounters an error loading an [url].
  final onWebViewLoadErrorCallback onLoadError;

  ///Event fires when the current [progress] of loading a page is changed.
  final onWebViewProgressChangedCallback onProgressChanged;

  ///Event fires when the [InAppWebView] receives a [ConsoleMessage].
  final onWebViewConsoleMessageCallback onConsoleMessage;

  ///Give the host application a chance to take control when a URL is about to be loaded in the current WebView.
  ///
  ///**NOTE**: In order to be able to listen this event, you need to set `useShouldOverrideUrlLoading` option to `true`.
  final shouldOverrideUrlLoadingCallback shouldOverrideUrlLoading;

  ///Event fires when the [InAppWebView] loads a resource.
  ///
  ///**NOTE**: In order to be able to listen this event, you need to set `useOnLoadResource` option to `true`.
  ///
  ///**NOTE only for iOS**: In some cases, the [response.data] of a [response] with `text/assets` encoding could be empty.
  final onWebViewLoadResourceCallback onLoadResource;

  ///Initial url that will be loaded.
  final String initialUrl;
  ///Initial asset file that will be loaded. See [InAppWebView.loadFile()] for explanation.
  final String initialFile;
  ///Initial headers that will be used.
  final Map<String, String> initialHeaders;
  ///Initial options that will be used.
  final Map<String, dynamic> initialOptions;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  const InAppWebView({
    Key key,
    this.initialUrl = "about:blank",
    this.initialFile,
    this.initialHeaders = const {},
    this.initialOptions = const {},
    this.onWebViewCreated,
    this.onLoadStart,
    this.onLoadStop,
    this.onLoadError,
    this.onConsoleMessage,
    this.onProgressChanged,
    this.shouldOverrideUrlLoading,
    this.onLoadResource,
    this.gestureRecognizers,
  }) : super(key: key);

  @override
  _InAppWebViewState createState() => _InAppWebViewState();
}

class _InAppWebViewState extends State<InAppWebView> {

  InAppWebViewController _controller;

  @override
  void dispose() {
    super.dispose();
    if (_controller != null) {
      _controller._dispose();
      _controller = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return GestureDetector(
        onLongPress: () {},
        child: AndroidView(
          viewType: 'com.pichillilorenzo/flutter_inappwebview',
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: widget.gestureRecognizers,
          layoutDirection: TextDirection.rtl,
          creationParams: <String, dynamic>{
              'initialUrl': widget.initialUrl,
              'initialFile': widget.initialFile,
              'initialHeaders': widget.initialHeaders,
              'initialOptions': widget.initialOptions
            },
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    }
    return Text(
        '$defaultTargetPlatform is not yet supported by the flutter_inappbrowser plugin');
  }

  @override
  void didUpdateWidget(InAppWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  void _onPlatformViewCreated(int id) {
    _controller = InAppWebViewController(id, widget);
    if (widget.onWebViewCreated != null) {
      widget.onWebViewCreated(_controller);
    }
  }
}

/// Controls an [InAppWebView] widget instance.
///
/// An [InAppWebViewController] instance can be obtained by setting the [InAppWebView.onWebViewCreated]
/// callback for an [InAppWebView] widget.
class InAppWebViewController {

  InAppWebView _widget;
  MethodChannel _channel;
  Map<String, List<JavaScriptHandlerCallback>> javaScriptHandlersMap = HashMap<String, List<JavaScriptHandlerCallback>>();
  bool _isOpened = false;
  int _id;
  String _inAppBrowserUuid;
  InAppBrowser _inAppBrowser;

  InAppWebViewController(int id, InAppWebView widget) {
    _id = id;
    _channel = MethodChannel('com.pichillilorenzo/flutter_inappwebview_$id');
    _channel.setMethodCallHandler(_handleMethod);
    _widget = widget;
  }

  InAppWebViewController.fromInAppBrowser(String uuid, MethodChannel channel, InAppBrowser inAppBrowser) {
    _inAppBrowserUuid = uuid;
    _channel = channel;
    _inAppBrowser = inAppBrowser;
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch(call.method) {
      case "onLoadStart":
        String url = call.arguments["url"];
        if (_widget != null)
          _widget.onLoadStart(this, url);
        else
          _inAppBrowser.onLoadStart(url);
        break;
      case "onLoadStop":
        String url = call.arguments["url"];
        if (_widget != null)
          _widget.onLoadStop(this, url);
        else
          _inAppBrowser.onLoadStop(url);
        break;
      case "onLoadError":
        String url = call.arguments["url"];
        int code = call.arguments["code"];
        String message = call.arguments["message"];
        if (_widget != null)
          _widget.onLoadError(this, url, code, message);
        else
          _inAppBrowser.onLoadError(url, code, message);
        break;
      case "onProgressChanged":
        int progress = call.arguments["progress"];
        if (_widget != null)
          _widget.onProgressChanged(this, progress);
        else
          _inAppBrowser.onProgressChanged(progress);
        break;
      case "shouldOverrideUrlLoading":
        String url = call.arguments["url"];
        if (_widget != null)
          _widget.shouldOverrideUrlLoading(this, url);
        else
          _inAppBrowser.shouldOverrideUrlLoading(url);
        break;
      case "onLoadResource":
        Map<dynamic, dynamic> rawResponse = call.arguments["response"];
        rawResponse = rawResponse.cast<String, dynamic>();
        Map<dynamic, dynamic> rawRequest = call.arguments["request"];
        rawRequest = rawRequest.cast<String, dynamic>();

        String urlResponse = rawResponse["url"];
        Map<dynamic, dynamic> headersResponse = rawResponse["headers"];
        headersResponse = headersResponse.cast<String, String>();
        int statusCode = rawResponse["statusCode"];
        int startTime = rawResponse["startTime"];
        int duration = rawResponse["duration"];
        Uint8List data = rawResponse["data"];

        String urlRequest = rawRequest["url"];
        Map<dynamic, dynamic> headersRequest = rawRequest["headers"];
        headersRequest = headersResponse.cast<String, String>();
        String method = rawRequest["method"];

        var response = new WebResourceResponse(urlResponse, headersResponse, statusCode, startTime, duration, data);
        var request = new WebResourceRequest(urlRequest, headersRequest, method);

        if (_widget != null)
          _widget.onLoadResource(this, response, request);
        else
          _inAppBrowser.onLoadResource(response, request);
        break;
      case "onConsoleMessage":
        String sourceURL = call.arguments["sourceURL"];
        int lineNumber = call.arguments["lineNumber"];
        String message = call.arguments["message"];
        ConsoleMessageLevel messageLevel;
        ConsoleMessageLevel.values.forEach((element) {
          if ("ConsoleMessageLevel." + call.arguments["messageLevel"] == element.toString()) {
            messageLevel = element;
            return;
          }
        });
        if (_widget != null)
          _widget.onConsoleMessage(this, ConsoleMessage(sourceURL, lineNumber, message, messageLevel));
        else
          _inAppBrowser.onConsoleMessage(ConsoleMessage(sourceURL, lineNumber, message, messageLevel));
        break;
      case "onCallJsHandler":
        String handlerName = call.arguments["handlerName"];
        List<dynamic> args = jsonDecode(call.arguments["args"]);
        if (javaScriptHandlersMap.containsKey(handlerName)) {
          for (var handler in javaScriptHandlersMap[handlerName]) {
            handler(args);
          }
        }
        break;
      default:
        throw UnimplementedError("Unimplemented ${call.method} method");
    }
  }

  ///Loads the given [url] with optional [headers] specified as a map from name to value.
  Future<void> loadUrl(String url, {Map<String, String> headers = const {}}) async {
    assert(url != null && url.isNotEmpty);
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened(message: 'Cannot laod $url!');
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    args.putIfAbsent('url', () => url);
    args.putIfAbsent('headers', () => headers);
    await _channel.invokeMethod('loadUrl', args);
  }

  ///Loads the given [url] with [postData] using `POST` method into this WebView.
  Future<void> postUrl(String url, Uint8List postData) async {
    assert(url != null && url.isNotEmpty);
    assert(postData != null);
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened(message: 'Cannot laod $url!');
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    args.putIfAbsent('url', () => url);
    args.putIfAbsent('postData', () => postData);
    await _channel.invokeMethod('postUrl', args);
  }

  ///Loads the given [data] into this WebView, using [baseUrl] as the base URL for the content.
  ///The [mimeType] parameter specifies the format of the data.
  ///The [encoding] parameter specifies the encoding of the data.
  Future<void> loadData(String data, {String mimeType = "text/html", String encoding = "utf8", String baseUrl = "about:blank"}) async {
    assert(data != null);
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    args.putIfAbsent('data', () => data);
    args.putIfAbsent('mimeType', () => mimeType);
    args.putIfAbsent('encoding', () => encoding);
    args.putIfAbsent('baseUrl', () => baseUrl);
    await _channel.invokeMethod('loadData', args);
  }

  ///Loads the given [assetFilePath] with optional [headers] specified as a map from name to value.
  ///
  ///To be able to load your local files (assets, js, css, etc.), you need to add them in the `assets` section of the `pubspec.yaml` file, otherwise they cannot be found!
  ///
  ///Example of a `pubspec.yaml` file:
  ///```yaml
  ///...
  ///
  ///# The following section is specific to Flutter.
  ///flutter:
  ///
  ///  # The following line ensures that the Material Icons font is
  ///  # included with your application, so that you can use the icons in
  ///  # the material Icons class.
  ///  uses-material-design: true
  ///
  ///  assets:
  ///    - assets/index.html
  ///    - assets/css/
  ///    - assets/images/
  ///
  ///...
  ///```
  ///Example of a `main.dart` file:
  ///```dart
  ///...
  ///inAppBrowser.loadFile("assets/index.html");
  ///...
  ///```
  Future<void> loadFile(String assetFilePath, {Map<String, String> headers = const {}}) async {
    assert(assetFilePath != null && assetFilePath.isNotEmpty);
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened(message: 'Cannot laod $assetFilePath!');
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    args.putIfAbsent('url', () => assetFilePath);
    args.putIfAbsent('headers', () => headers);
    await _channel.invokeMethod('loadFile', args);
  }

  ///Reloads the [InAppWebView] window.
  Future<void> reload() async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    await _channel.invokeMethod('reload', args);
  }

  ///Goes back in the history of the [InAppWebView] window.
  Future<void> goBack() async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    await _channel.invokeMethod('goBack', args);
  }

  ///Returns a Boolean value indicating whether the [InAppWebView] can move backward.
  Future<bool> canGoBack() async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    return await _channel.invokeMethod('canGoBack', args);
  }

  ///Goes forward in the history of the [InAppWebView] window.
  Future<void> goForward() async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    await _channel.invokeMethod('goForward', args);
  }

  ///Returns a Boolean value indicating whether the [InAppWebView] can move forward.
  Future<bool> canGoForward() async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    return await _channel.invokeMethod('canGoForward', args);
  }

  ///Check if the Web View of the [InAppWebView] instance is in a loading state.
  Future<bool> isLoading() async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    return await _channel.invokeMethod('isLoading', args);
  }

  ///Stops the Web View of the [InAppWebView] instance from loading.
  Future<void> stopLoading() async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    await _channel.invokeMethod('stopLoading', args);
  }

  ///Injects JavaScript code into the [InAppWebView] window and returns the result of the evaluation.
  Future<String> injectScriptCode(String source) async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    args.putIfAbsent('source', () => source);
    return await _channel.invokeMethod('injectScriptCode', args);
  }

  ///Injects a JavaScript file into the [InAppWebView] window.
  Future<void> injectScriptFile(String urlFile) async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    args.putIfAbsent('urlFile', () => urlFile);
    await _channel.invokeMethod('injectScriptFile', args);
  }

  ///Injects CSS into the [InAppWebView] window.
  Future<void> injectStyleCode(String source) async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    args.putIfAbsent('source', () => source);
    await _channel.invokeMethod('injectStyleCode', args);
  }

  ///Injects a CSS file into the [InAppWebView] window.
  Future<void> injectStyleFile(String urlFile) async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    args.putIfAbsent('urlFile', () => urlFile);
    await _channel.invokeMethod('injectStyleFile', args);
  }

  ///Adds/Appends a JavaScript message handler [callback] ([JavaScriptHandlerCallback]) that listen to post messages sent from JavaScript by the handler with name [handlerName].
  ///Returns the position `index` of the handler that can be used to remove it with the [removeJavaScriptHandler()] method.
  ///
  ///The Android implementation uses [addJavascriptInterface](https://developer.android.com/reference/android/webkit/WebView#addJavascriptInterface(java.lang.Object,%20java.lang.String)).
  ///The iOS implementation uses [addScriptMessageHandler](https://developer.apple.com/documentation/webkit/wkusercontentcontroller/1537172-addscriptmessagehandler?language=objc)
  ///
  ///The JavaScript function that can be used to call the handler is `window.flutter_inappbrowser.callHandler(handlerName <String>, ...args);`, where `args` are [rest parameters](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/rest_parameters).
  ///The `args` will be stringified automatically using `JSON.stringify(args)` method and then they will be decoded on the Dart side.
  int addJavaScriptHandler(String handlerName, JavaScriptHandlerCallback callback) {
    this.javaScriptHandlersMap.putIfAbsent(handlerName, () => List<JavaScriptHandlerCallback>());
    this.javaScriptHandlersMap[handlerName].add(callback);
    return this.javaScriptHandlersMap[handlerName].indexOf(callback);
  }

  ///Removes a JavaScript message handler previously added with the [addJavaScriptHandler()] method in the [handlerName] list by its position [index].
  ///Returns `true` if the callback is removed, otherwise `false`.
  bool removeJavaScriptHandler(String handlerName, int index) {
    try {
      this.javaScriptHandlersMap[handlerName].removeAt(index);
      return true;
    }
    on RangeError catch(e) {
      print(e);
    }
    return false;
  }

  ///Takes a screenshot (in PNG format) of the WebView's visible viewport and returns a `Uint8List`. Returns `null` if it wasn't be able to take it.
  ///
  ///**NOTE for iOS**: available from iOS 11.0+.
  Future<Uint8List> takeScreenshot() async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    return await _channel.invokeMethod('takeScreenshot', args);
  }

  ///Sets the [InAppWebView] options with the new [options] and evaluates them.
  Future<void> setOptions(Map<String, dynamic> options) async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    args.putIfAbsent('options', () => options);
    args.putIfAbsent('optionsType', () => "InAppBrowserOptions");
    await _channel.invokeMethod('setOptions', args);
  }

  ///Gets the current [InAppWebView] options. Returns `null` if the options are not setted yet.
  Future<Map<String, dynamic>> getOptions() async {
    Map<String, dynamic> args = <String, dynamic>{};
    if (_inAppBrowserUuid != null) {
      _inAppBrowser._throwIsNotOpened();
      args.putIfAbsent('uuid', () => _inAppBrowserUuid);
    }
    args.putIfAbsent('optionsType', () => "InAppBrowserOptions");
    Map<dynamic, dynamic> options = await _ChannelManager.channel.invokeMethod('getOptions', args);
    options = options.cast<String, dynamic>();
    return options;
  }

  Future<void> _dispose() async {
    await _channel.invokeMethod('dispose');
  }

}

///InAppLocalhostServer class.
///
///This class allows you to create a simple server on `http://localhost:[port]/` in order to be able to load your assets file on a server. The default [port] value is `8080`.
class InAppLocalhostServer {

  HttpServer _server;
  int _port = 8080;

  InAppLocalhostServer({int port = 8080}) {
    this._port = port;
  }

  ///Starts a server on http://localhost:[port]/.
  ///
  ///**NOTE for iOS**: For the iOS Platform, you need to add the `NSAllowsLocalNetworking` key with `true` in the `Info.plist` file (See [ATS Configuration Basics](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW35)):
  ///```xml
  ///<key>NSAppTransportSecurity</key>
  ///<dict>
  ///    <key>NSAllowsLocalNetworking</key>
  ///    <true/>
  ///</dict>
  ///```
  ///The `NSAllowsLocalNetworking` key is available since **iOS 10**.
  Future<void> start() async {

    if (this._server != null) {
      throw Exception('Server already started on http://localhost:$_port');
    }

    var completer = new Completer();

    runZoned(() {
      HttpServer.bind('127.0.0.1', _port).then((server) {
        print('Server running on http://localhost:' + _port.toString());

        this._server = server;

        server.listen((HttpRequest request) async {
          var body = List<int>();
          var path = request.requestedUri.path;
          path = (path.startsWith('/')) ? path.substring(1) : path;
          path += (path.endsWith('/')) ? 'index.html' : '';

          try {
            body = (await rootBundle.load(path))
                .buffer.asUint8List();
          } catch (e) {
            print(e.toString());
            request.response.close();
            return;
          }

          var contentType = ['text', 'html'];
          if (!request.requestedUri.path.endsWith('/') && request.requestedUri.pathSegments.isNotEmpty) {
            var mimeType = lookupMimeType(request.requestedUri.path, headerBytes: body);
            if (mimeType != null) {
              contentType = mimeType.split('/');
            }
          }

          request.response.headers.contentType = new ContentType(contentType[0], contentType[1], charset: 'utf-8');
          request.response.add(body);
          request.response.close();
        });

        completer.complete();
      });
    }, onError: (e, stackTrace) => print('Error: $e $stackTrace'));

    return completer.future;
  }

  ///Closes the server.
  Future<void> close() async {
    if (this._server != null) {
      await this._server.close(force: true);
      print('Server running on http://localhost:$_port closed');
      this._server = null;
    }
  }

}