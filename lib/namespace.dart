library socket.io.dart.namespace;

import 'package:logging/logging.dart';
import './index.dart';
import './client.dart';


/**
 * Module dependencies.
 */

//var Socket = require('./socket');
//var Emitter = require('events').EventEmitter;
//var parser = require('socket.io-parser');
//var debug = require('debug')('socket.io:namespace');
//var hasBin = require('has-binary');


/**
 * Blacklisted events.
 */

List<String> events = [
    'connect',    // for symmetry with client
    'connection',
    'newListener'
];

/**
 * Flags.
 */
List<String> flags = [
    'json',
    'volatile'
];

/**
 * @todo to remove when socket will be implemented
 */
class Socket {
    Socket(Namespace ns, Client client);
}

enum ParserType {
    event,
    binaryEvent
}

class Namespace {
    String name;
    Server server;
    List sockets = [];
    Map connected = {};
    List fns = [];
    Map acks = {};
    int ids = 0;
    List rooms = [];
    Map flags = {};
    Logger _logger = new Logger('socket.io:namespace');

    /**
     * Namespace constructor.
     *
     * @param {Server} server instance
     * @param {Socket} name
     * @api private
     */
    Namespace(Server this.server, String this.name) {
        this.initAdapter();
    }

    /**
     * Initializes the `Adapter` for this nsp.
     * Run upon changing adapter by `Server#adapter`
     * in addition to the constructor.
     *
     * @api private
     */
    initAdapter() {
        // @todo Check what to do with that
        // this.adapter = new (this.server.adapter())(this);
    }

    /**
     * Sets up namespace middleware.
     *
     * @return {Namespace} self
     * @api public
     */
    use(fn) {
        this.fns.add(fn);
        return this;
    }

    /**
     * Executes the middleware for an incoming client.
     *
     * @param {Socket} socket that will get added
     * @param {Function} last fn call in the middleware
     * @api private
     */
    run(socket, fn) {
        var fns = this.fns.slice(0);
        if (!fns.length) return fn(null);
// @todo export to private method
//        function run(i){
//            fns[i](socket, function(err){
//            // upon error, short-circuit
//            if (err) return fn(err);
//
//            // if no middleware left, summon callback
//            if (!fns[i + 1]) return fn(null);
//
//            // go on to next
//            run(i + 1);
//        })

//        run(0);
    }

    /**
     * Targets a room when emitting.
     *
     * @param {String} name
     * @return {Namespace} self
     * @api public
     */
    In(String name) {
        to(name);
    }

    /**
     * Targets a room when emitting.
     *
     * @param {String} name
     * @return {Namespace} self
     * @api public
     */
    to(String name) {
        rooms = this.rooms.isEmpty ? this.rooms : [];
        if (!rooms.contains(name)) this.rooms.add(name);
        return this;
    }

    /**
     * Adds a new client.
     *
     * @return {Socket}
     * @api private
     */
    add(Client client, fn){
        _logger.info('adding socket to nsp ${this.name}');
        var socket = new Socket(this, client);
        var self = this;
        this.run(socket, (err) {
            if ('open' == client.conn.readyState) {
                if (err) return socket.error(err.data || err.message);

                // track socket
                self.sockets.push(socket);

                // it's paramount that the internal `onconnect` logic
                // fires before user-set events to prevent state order
                // violations (such as a disconnection before the connection
                // logic is complete)
                socket.onconnect();
                if (fn) fn();

                // fire user-set events
                self.emit('connect', socket);
                self.emit('connection', socket);
            } else {
                _logger.info('next called after client was closed - ignoring socket');
            }
        });
        return socket;
    }

    /**
     * Removes a client. Called by each `Socket`.
     *
     * @api private
     */
    remove(socket) {
        if (this.sockets.contains(socket)) {
            this.sockets.remove(socket);
        } else {
            _logger.info('ignoring remove for ${socket.id}');
        }
    }

    /**
     * Emits to all clients.
     *
     * @return {Namespace} self
     * @api public
     */
    emit(ev, [dynamic arguments]) {
        if (events.contains(ev)) {
            emit(this, arguments);
        } else {
            // set up packet object
            ParserType parserType = ParserType.event; // default
            // @todo check how to handle it with Dart
            // if (hasBin(args)) { parserType = ParserType.binaryEvent; } // binary

            Map packet = {'type': parserType, 'data': args};

            this.adapter.broadcast(packet, {
                rooms: this.rooms,
                flags: this.flags
            });

            this.rooms = null;
            this.flags = null;
        }

        return this;
    }

    /**
     * Sends a `message` event to all clients.
     *
     * @return {Namespace} self
     * @api public
     */
    send([args]) {
        write(args);
    }

    write([args]) {
        args.unshift('message');
        this.emit(this, args);
        return this;
    }

    /**
     * Gets a list of clients.
     *
     * @return {Namespace} self
     * @api public
     */
    clients(fn) {
        this.adapter.clients(this.rooms, fn);
        return this;
    }

    /**
     * Sets the compress flag.
     *
     * @param {Boolean} if `true`, compresses the sending data
     * @return {Socket} self
     * @api public
     */
    compress(compress) {
        this.flags = this.flags.isEmpty ? this.flags : {};
        this.flags['compress'] = compress;
        return this;
    }
}

/**
 * Apply flags from `Socket`.
 */
// @todo
//exports.flags.forEach(function(flag){
//    Namespace.prototype.__defineGetter__(flag, function(){
//    this.flags = this.flags || {};
//    this.flags[flag] = true;
//    return this;
//    });
//});
