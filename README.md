# socket.io.dart
Port of awesome JavaScript Node.js library - Socket.io - in Dart

Library is under heavy development, use it on your own risk! New updates soon :)
Issues are disabled until sources will be migrated.

## Few words about this project:

I've decided to rewrite socket.io to Dart since there is no good alternative for this awesome library in Dart. I want to create something that will be compatible with current client-side socket.io.
In first phase I want to migrate key libraries changing only syntax to Dart-compatible, such as:

* socket.io
* engine.io
* socket.io-adapter
* socket.io-client
    
I know there will be a lot of errors, because of using node.js objects, but that will be done after migrating sources. 
That's why I don't attach any build server configuration for this project - just after target classes will be migrated to fully functional Dart classes, I want to rewrite the tests (there shouldn't be any problem though).

## "That's crazy idea..."
Yes, I know. I do it on my own risk. I know socket-io evolves quickly but my main target is to ship basic functionality. In my opinion, Dart is great language that has chance to be used as an alternative to JavaScript in browsers.
Recently I've started to rewrite one of my application from node to Dart and I have to say the code looks excellent, debugging is much easier, performance is even better than its previous version.
In final phase I met a problem with no socket.io equivalent for Dart. I've spent so much time rewriting my app and I can't leave it now only because I can't use socket.io functionality there. That's why I decided to do so.
As I've already said, it a big risk because when I'll finish this project, it can be outdated. But I believe in strength of GitHub community and I know I can count on you! :)

## "...but I miss socket.io in Dart, too"
Any help is appreciated! If you want to contact me somehow, you can follow me on Twitter ([@eps1990](https://twitter.com/eps1990)) or Google+ ([+KubaTurek](https://plus.google.com/+KubaTurek)). 
