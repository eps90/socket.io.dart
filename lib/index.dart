library socket.io.dart;

import 'dart:io';
import 'package:logging/logging.dart';
import './client.dart';

/**
 * Module dependencies.
 */

//var http = require('http');
//var read = require('fs').readFileSync;
//var parse = require('url').parse;
//var engine = require('engine.io');
//var client = require('socket.io-client');
//var clientVersion = require('socket.io-client/package').version;
//var Client = require('./client');
//var Namespace = require('./namespace');
//var Adapter = require('socket.io-adapter');
//var debug = require('debug')('socket.io:server');
//var url = require('url');

/**
 * Socket.IO client source.
 */

//var clientSource = read(require.resolve('socket.io-client/socket.io.js'), 'utf-8');

/**
 * Old settings for backwards compatibility
 */
Map oldSettings = {
    "transports": "transports",
    "heartbeat timeout": "pingTimeout",
    "heartbeat interval": "pingInterval",
    "destroy buffer size": "maxHttpBufferSize"
};

/**
 * @todo to remove when socket-io.adapter will be migrated
 */
class Adapter {}

/**
 * @todo to remove namespace class will be implemented
 */
class Namespace {
    Server server;
    Namespace(Server this.server, String name);
    initAdapter() {}
}

/**
 * @todo to remove when engine-io will be migrated
 */
class Engine {
    on(String event, Function handler) {}
    close() {}
}

class Server {
    // Namespaces
    Map nsps = {};
    dynamic sockets;
    dynamic _origins;
    bool _serveClient;
    String _path;
    Adapter _adapter;
    HttpServer httpServer;
    Engine engine;

    Logger _logger = new Logger('socket.io:server');

    /**
     * Server constructor.
     *
     * @param {http.Server|Number|Object} http server, port or options
     * @param {Object} options
     * @api public
     */
    Server({srv: null, Map opts: const {}}) {
        opts = opts.isEmpty ? opts : {};
        this.nsps = {};
        this.path(opts.containsKey('path') ? opts['path'] : '/socket.io');
        this.serveClient(false != opts['serveClient']);
        this.adapter(opts.containsKey('adapter') ? opts['adapter'] : Adapter);
        this.origins(opts.containsKey('origins') ? opts['origins'] : '*:*');
        this.sockets = this.of('/');

        if (srv != null) {
            this.attach(srv, opts);
        }
    }

    /**
     * Server request verification function, that checks for allowed origins
     *
     * @param {http.IncomingMessage} request
     * @param {Function} callback to be called with the result: `fn(err, success)`
     */
    checkRequest(HttpRequest req, [Function fn]) {
        String origin = req.headers.value('origin') != null
            ? req.headers.value('origin')
            : req.headers.value('referer');

        // file:// URLs produce a null Origin which can't be authorized via echo-back
        if (origin == null || origin.isEmpty) {
            origin = '*';
        }

        if (!origin.isEmpty && this._origins is Function) {
            return this._origins(origin, fn);
        }

        if (this._origins.contains('*:*')) {
            return fn(null, true);
        }

        if (!origin.isEmpty) {
            try {
                Uri parts = Uri.parse(origin);
                int defaultPort = 'https:' == parts.scheme ? 443 : 80;
                int port = parts.port != null
                    ? parts.port
                    : defaultPort;
                bool ok =
                    ~this._origins.indexOf(parts.host + ':' + port.toString())
                    || ~this._origins.indexOf(parts.host + ':*')
                    || ~this._origins.indexOf('*:' + port.toString());

                return fn(null, !!ok);
            } catch (ex) {
            }
        }

        fn(null, false);
    }

    /**
     * Sets/gets whether client code is being served.
     *
     * @param {Boolean} whether to serve client code
     * @return {Server|Boolean} self when setting or value when getting
     * @api public
     */
    serveClient([bool v]) {
        if (v == null) {
            return this._serveClient;
        }

        this._serveClient = v;
        return this;
    }

    /**
     * Backwards compatiblity.
     *
     * @api public
     */
    set(String key, [val]){
        if ('authorization' == key && val != null) {
            this.use((socket, next) {
                val(socket.request, (err, authorized) {
                    if (err) {
                        return next(new Exception(err));
                    };
                    if (!authorized) {
                        return next(new Exception('Not authorized'));
                    }

                    next();
                });
            });
        } else if ('origins' == key && val != null) {
            this.origins(val);
        } else if ('resource' == key) {
            this.path(val);
        } else if (oldSettings[key] && this.eio[oldSettings[key]]) {
            this.eio[oldSettings[key]] = val;
        } else {
            _logger.severe('Option $key is not valid. Please refer to the README.');
        }

        return this;
    }

    /**
     * Sets the client serving path.
     *
     * @param {String} pathname
     * @return {Server|String} self when setting or value when getting
     * @api public
     */
    path([String v]) {
        if (v == null || v.isEmpty) return this._path;
        this._path = v.replaceFirst(new RegExp(r'/\/$/'), '');
        return this;
    }

    /**
     * Sets the adapter for rooms.
     *
     * @param {Adapter} pathname
     * @return {Server|Adapter} self when setting or value when getting
     * @api public
     */
    adapter([Adapter v]){
        if (v == null) return this._adapter;
        this._adapter = v;
        this.nsps.forEach((dynamic i, Namespace nsp) {
            this.nsps[i].initAdapter();
        });

        return this;
    }

    /**
     * Sets the allowed origins for requests.
     *
     * @param {String} origins
     * @return {Server|Adapter} self when setting or value when getting
     * @api public
     */

    origins([String v]){
        if (v == null || v.isEmpty) return this._origins;

        this._origins = v;
        return this;
    }

    /**
     * Attaches socket.io to a server or port.
     *
     * @param {http.Server|Number} server or port
     * @param {Object} options passed to engine.io
     * @return {Server} self
     * @api public
     */
    listen(srv,[Map opts = const {}]) {
        attach(srv, opts);
    }

    /**
     * Attaches socket.io to a server or port.
     *
     * @param {http.Server|Number} server or port
     * @param {Object} options passed to engine.io
     * @return {Server} self
     * @api public
     */
    attach(srv, [Map opts = const {}]) {
        if (srv is Function) {
            String msg = 'You are trying to attach socket.io to an express ' +
            'request handler function. Please pass a http.Server instance.';
            throw new Exception(msg);
        }

        // handle a port as a string
        if (srv is String && int.parse(srv.toString()).toString() == srv) {
            srv = int.parse(srv.toString());
        }

        if (srv is num) {
            _logger.info('creating http server and binding to $srv');
            int port = srv;
            HttpServer.bind(InternetAddress.ANY_IP_V4, port).then((HttpServer server) {
                this.httpServer = server;
                server.listen((HttpRequest request) {
                    HttpResponse response = request.response;
                    response.statusCode = HttpStatus.NOT_FOUND;
                    response.close();
                });
            });
        }

        // set engine.io path to `/socket.io`
        opts['path'] = opts.containsKey('path') ? opts['path'] : this.path();
        // set origins verification
        opts['allowRequest'] = this.checkRequest;

        // initialize engine
        _logger.info('creating engine.io instance with opts $opts');
        this.eio = engine.attach(srv, opts);

        // attach static file serving
        if (this._serveClient) this.attachServe(srv);

        // Export http server
        this.httpServer = srv;

        // bind to engine events
        this.bind(this.eio);

        return this;
    }

    /**
     * Attaches the static file serving.
     *
     * @param {Function|http.Server} http server
     * @api private
     * @todo Include better way to serve files
     */
//    attachServe(srv){
//        _logger.info('attaching client serving req handler');
//        var url = this._path + '/socket.io.js';
//        var evs = srv.listeners('request').slice(0);
//        var self = this;
//        srv.removeAllListeners('request');
//        srv.on('request', function(req, res) {
//        if (0 === req.url.indexOf(url)) {
//        self.serve(req, res);
//        } else {
//        for (var i = 0; i < evs.length; i++) {
//        evs[i].call(srv, req, res);
//        }
//        }
//        })
//    }

    /**
     * Handles a request serving `/socket.io.js`
     *
     * @param {http.Request} req
     * @param {http.Response} res
     * @api private
     * @todo Include better way to serve files
     */

//    serve(req, res){
//        var etag = req.headers['if-none-match'];
//        if (etag) {
//            if (clientVersion == etag) {
//                debug('serve client 304');
//                res.writeHead(304);
//                res.end();
//                return;
//            }
//        }
//
//        debug('serve client source');
//        res.setHeader('Content-Type', 'application/javascript');
//        res.setHeader('ETag', clientVersion);
//        res.writeHead(200);
//        res.end(clientSource);
//    }

    /**
     * Binds socket.io to an engine.io instance.
     *
     * @param {engine.Server} engine.io (or compatible) server
     * @return {Server} self
     * @api public
     */
    bind(engine){
        this.engine = engine;
        this.engine.on('connection', this.onconnection);
        return this;
    }

    /**
     * Called with each incoming transport connection.
     *
     * @param {engine.Socket} socket
     * @return {Server} self
     * @api public
     */
    onconnection(conn){
        _logger.info('incoming connection with id ${conn.id}');
        Client client = new Client(this, conn);
        client.connect('/');
        return this;
    }


    /**
     * Looks up a namespace.
     *
     * @param {String} nsp name
     * @param {Function} optional, nsp `connection` ev handler
     * @api public
     */

    of(name,[fn]) {
        if (name.toString()[0] != '/') {
            name = '/' + name;
        }

        if (!this.nsps[name]) {
            _logger.info('initializing namespace $name');
            Namespace nsp = new Namespace(this, name);
            this.nsps[name] = nsp;
        }
        if (fn) this.nsps[name].on('connect', fn);
        return this.nsps[name];
    }

    /**
     * Closes server connection
     *
     * @api public
     */
    close() {
        this.nsps['/'].sockets.forEach((socket) {
            socket.onclose();
        });

        this.engine.close();

        if (this.httpServer != null) {
            this.httpServer.close();
        }
    }
}


/**
 * Expose main namespace (/).
 */

//['on', 'to', 'in', 'use', 'emit', 'send', 'write', 'clients', 'compress'].forEach(function(fn){
//    Server.prototype[fn] = function(){
//        var nsp = this.sockets[fn];
//        return nsp.apply(this.sockets, arguments);
//    };
//});
//
//Namespace.flags.forEach(function(flag){
//    Server.prototype.__defineGetter__(flag, function(){
//    this.sockets.flags = this.sockets.flags || {};
//    this.sockets.flags[flag] = true;
//    return this;
//    });
//});

