part of socket.io;


/**
 * Module dependencies.
 */

//var Emitter = require('events').EventEmitter;
//var parser = require('socket.io-parser');
//var url = require('url');
//var debug = require('debug')('socket.io:socket');
//var hasBin = require('has-binary');

/**
 * Module exports.
 */
//
//module.exports = exports = Socket;

/**
 * Blacklisted events.
 *
 * @api public
 */

List events = [
    'error',
    'connect',
    'disconnect',
    'newListener',
    'removeListener'
];

/**
 * Flags.
 *
 * @api private
 */

List flags = [
    'json',
    'volatile',
    'broadcast'
];

/**
 * `EventEmitter#emit` reference.
 */

//var emit = Emitter.prototype.emit;

/**
 * Interface to a `Client` for a given `Namespace`.
 *
 * @param {Namespace} nsp
 * @param {Client} client
 * @api public
 */

/**
 * @todo remove when adapter will be implemented
 */
class Adapter {}

class Socket {
    Namespace nsp;
    Client client;
    Server server;
    Adapter adapter;
    int id;
    var request;
    var conn;
    List rooms = [];
    Map acks = {};
    bool connected = true;
    bool disconnected = false;

    Socket(Namespace this.nsp, Client this.client) {
        this.server = nsp.server;
        this.adapter = this.nsp.adapter;
        this.id = client.id;
        this.request = client.request;
        this.conn = client.conn;
        this.handshake = this.buildHandshake();
    }

    /**
     * Builds the `handshake` BC object
     *
     * @api private
     */
    buildHandshake() {
        return {
            headers: this.request.headers,
            time: new DateTime.now().toString(),
            address: this.conn.remoteAddress,
            xdomain: !!this.request.headers.origin,
            secure: !!this.request.connection.encrypted,
            issued: new DateTime.now().millisecondsSinceEpoch,
            url: this.request.url,
            query: url.parse(this.request.url, true).query || {}
        };
    }

    /**
     * Emits to this client.
     *
     * @return {Socket} self
     * @api public
     */
    emit (ev){
        if (~exports.events.indexOf(ev)) {
            emit.apply(this, arguments);
        } else {
            var args = Array.prototype.slice.call(arguments);
            var packet = {};
            packet.type = hasBin(args) ? parser.BINARY_EVENT : parser.EVENT;
            packet.data = args;
            var flags = this.flags || {};

            // access last argument to see if it's an ACK callback
//            @todo
//            if ('function' == typeof args[args.length - 1]) {
//                if (this._rooms || flags.broadcast) {
//                    throw new Error('Callbacks are not supported when broadcasting');
//                }
//
//                debug('emitting packet with ack id %d', this.nsp.ids);
//                this.acks[this.nsp.ids] = args.pop();
//                packet.id = this.nsp.ids++;
//            }

            if (this._rooms || flags.broadcast) {
                this.adapter.broadcast(packet, {
                    except: [this.id],
                    rooms: this._rooms,
                    flags: flags
                });
            } else {
                // dispatch packet
                this.packet(packet, {
                    volatile: flags.volatile,
                    compress: flags.compress
                });
            }

            // reset flags
            this._rooms = null;
            this.flags = null;
        }
        return this;
    }


    /**
     * Targets a room when broadcasting.
     *
     * @param {String} name
     * @return {Socket} self
     * @api public
     */
    to(String name) {
        In(name);
    }

    In (name){
        this._rooms = this._rooms || [];
        if (!~this._rooms.indexOf(name)) this._rooms.push(name);
        return this;
    }

    /**
     * Sends a `message` event.
     *
     * @return {Socket} self
     * @api public
     */
    send() {
        write();
    }

    write (){
        var args = Array.prototype.slice.call(arguments);
        args.unshift('message');
        this.emit.apply(this, args);
        return this;
    }

    /**
     * Writes a packet.
     *
     * @param {Object} packet object
     * @param {Object} options
     * @api private
     */
    packet(packet, opts){
        packet.nsp = this.nsp.name;
        opts = opts || {};
        opts.compress = false != opts.compress;
        this.client.packet(packet, opts);
    }

    /**
     * Joins a room.
     *
     * @param {String} room
     * @param {Function} optional, callback
     * @return {Socket} self
     * @api private
     */
    join(room, fn){
        debug('joining room %s', room);
        var self = this;
        if (~this.rooms.indexOf(room)) return this;
        this.adapter.add(this.id, room, (err){
        if (err) return fn && fn(err);
        debug('joined room %s', room);
        self.rooms.push(room);
        fn && fn(null);
        });
        return this;
    }

    /**
     * Leaves a room.
     *
     * @param {String} room
     * @param {Function} optional, callback
     * @return {Socket} self
     * @api private
     */
    leave(room, fn){
        debug('leave room %s', room);
        var self = this;
        this.adapter.del(this.id, room, (err){
        if (err) return fn && fn(err);
        debug('left room %s', room);
        var idx = self.rooms.indexOf(room);
        if (idx >= 0) {
        self.rooms.splice(idx, 1);
        }
        fn && fn(null);
        });
        return this;
    }

    /**
     * Leave all rooms.
     *
     * @api private
     */

    leaveAll(){
        this.adapter.delAll(this.id);
        this.rooms = [];
    }

    /**
     * Called by `Namespace` upon succesful
     * middleware execution (ie: authorization).
     *
     * @api private
     */

    onconnect(){
        debug('socket connected - writing packet');
        this.nsp.connected[this.id] = this;
        this.join(this.id);
        this.packet({ type: parser.CONNECT });
    }

    /**
     * Called with each packet. Called by `Client`.
     *
     * @param {Object} packet
     * @api private
     */

    onpacket(packet){
        debug('got packet %j', packet);
        switch (packet.type) {
            case parser.EVENT:
                this.onevent(packet);
                break;

            case parser.BINARY_EVENT:
                this.onevent(packet);
                break;

            case parser.ACK:
                this.onack(packet);
                break;

            case parser.BINARY_ACK:
                this.onack(packet);
                break;

            case parser.DISCONNECT:
                this.ondisconnect();
                break;

            case parser.ERROR:
                this.emit('error', packet.data);
        }
    }

    /**
     * Called upon event packet.
     *
     * @param {Object} packet object
     * @api private
     */
    onevent(packet){
        var args = packet.data || [];
        debug('emitting event %j', args);

        if (null != packet.id) {
            debug('attaching ack callback to event');
            args.push(this.ack(packet.id));
        }

        emit.apply(this, args);
    }

    /**
     * Produces an ack callback to emit with an event.
     *
     * @param {Number} packet id
     * @api private
     */
    ack(id){
        var self = this;
        var sent = false;
        return function(){
            // prevent double callbacks
            if (sent) return;
            var args = Array.prototype.slice.call(arguments);
            debug('sending ack %j', args);

            var type = hasBin(args) ? parser.BINARY_ACK : parser.ACK;
            self.packet({
                id: id,
                type: type,
                data: args
            });
        };
    }

    /**
     * Called upon ack packet.
     *
     * @api private
     */
    onack(packet){
        var ack = this.acks[packet.id];
        if (ack is Function) {
            debug('calling ack %s with %j', packet.id, packet.data);
            ack.apply(this, packet.data);
            this.acks.remove(packet.id);
        } else {
            debug('bad ack %s', packet.id);
        }
    }

    /**
     * Called upon client disconnect packet.
     *
     * @api private
     */
    ondisconnect(){
        debug('got disconnect packet');
        this.onclose('client namespace disconnect');
    }

    /**
     * Handles a client error.
     *
     * @api private
     */
    onerror (err){
        if (this.listeners('error').length) {
            this.emit('error', err);
        } else {
            console.error('Missing error handler on `socket`.');
            console.error(err.stack);
        }
    }

    /**
     * Called upon closing. Called by `Client`.
     *
     * @param {String} reason
     * @param {Error} optional error object
     * @api private
     */
    onclose (reason){
        if (!this.connected) return this;
        debug('closing socket - reason %s', reason);
        this.leaveAll();
        this.nsp.remove(this);
        this.client.remove(this);
        this.connected = false;
        this.disconnected = true;
        this.nsp.connected.remove(this.id);
        this.emit('disconnect', reason);
    }

    /**
     * Produces an `error` packet.
     *
     * @param {Object} error object
     * @api private
     */
    error (err){
        this.packet({ type: parser.ERROR, data: err });
    }

    /**
     * Disconnects this client.
     *
     * @param {Boolean} if `true`, closes the underlying connection
     * @return {Socket} self
     * @api public
     */

    disconnect(close){
        if (!this.connected) return this;
        if (close) {
            this.client.disconnect();
        } else {
            this.packet({ type: parser.DISCONNECT });
            this.onclose('server namespace disconnect');
        }
        return this;
    }

    /**
     * Sets the compress flag.
     *
     * @param {Boolean} if `true`, compresses the sending data
     * @return {Socket} self
     * @api public
     */
    compress(compress){
        this.flags = this.flags || {};
        this.flags.compress = compress;
        return this;
    }
}

/**
 * Inherits from `EventEmitter`.
 */

//Socket.prototype.__proto__ = Emitter.prototype;

/**
 * Apply flags from `Socket`.
 */

//flags.forEach(function(flag){
//    Socket.prototype.__defineGetter__(flag, function(){
//    this.flags = this.flags || {};
//    this.flags[flag] = true;
//    return this;
//    });
//});

/**
 * `request` engine.io shorcut.
 *
 * @api public
 */

//Socket.prototype.__defineGetter__('request', function(){
//    return this.conn.request;
//});










