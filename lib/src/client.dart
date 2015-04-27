part of socket.io;

/**
 * Module dependencies.
 */

//var parser = require('socket.io-parser');
//var debug = require('debug')('socket.io:client');

/**
 * @todo to remove when parser module will be migrated
 */

class Encoder {
    on(String event, Function callback) {}
}

/**
 * @todo to remove when parser module will be migrated
 */
class Decoder {
    on(String event, Function callback) {}
}

class Client {
    Server server;
    dynamic conn;
    dynamic id;
    dynamic request;
    Encoder encoder;
    Decoder decoder;
    List sockets = [];
    Map nsps = {};
    List connectBuffer = [];
    Logger _logger = new Logger('socket.io:client');

    /**
     * Client constructor.
     *
     * @param {Server} server instance
     * @param {Socket} connection
     * @api private
     */
    Client(Server this.server, this.conn) {
        this.encoder = new Encoder();
        this.decoder = new Decoder();
        this.id = conn.id;
        this.request = conn.request;
        this.setup();
    }

    /**
     * Sets up event listeners.
     *
     * @api private
     */
    setup() {
        this.decoder.on('decoded', this.ondecoded);
        this.conn.on('data', this.ondata);
        this.conn.on('error', this.onerror);
        this.conn.on('close', this.onclose);
    }

    /**
     * Connects a client to a namespace.
     *
     * @param {String} namespace name
     * @api private
     */
    connect(name) {
        _logger.info('connecting to namespace $name');
        if (!this.server.nsps[name]) {
            this.packet({'type': parser.ERROR, 'nsp': name, 'data': 'Invalid namespace'});
            return;
        }
        var nsp = this.server.of(name);
        if ('/' != name && !this.nsps['/']) {
            this.connectBuffer.add(name);
            return;
        }

        var self = this;
        nsp.add(this,(socket) {
            self.sockets.add(socket);
            self.nsps[nsp.name] = socket;

            if ('/' == nsp.name && self.connectBuffer.length > 0) {
                self.connectBuffer.forEach(self.connect);
                self.connectBuffer = [];
            }
        });
    }

    /**
     * Disconnects from all namespaces and closes transport.
     *
     * @api private
     */
    disconnect() {
        var socket;
        // we don't use a for loop because the length of
        // `sockets` changes upon each iteration
        this.sockets.forEach((socket) {
            socket.disconnect();
        });
        this.sockets.clear();

        this.close();
    }

    /**
     * Removes a socket. Called by each `Socket`.
     *
     * @api private
     */
    remove (socket) {
        var i = this.sockets.indexOf(socket);
        if (~i) {
            var nsp = this.sockets[i].nsp.name;
            this.sockets.removeAt(i);
            this.nsps.remove(nsp);
        } else {
            _logger.info('ignoring remove for ${socket.id}');
        }
    }

    /**
     * Closes the underlying connection.
     *
     * @api private
     */
    close() {
        if ('open' == this.conn.readyState) {
            _logger.info('forcing transport close');
            this.conn.close();
            this.onclose('forced server close');
        }
    }

    /**
     * Writes a packet to the transport.
     *
     * @param {Object} packet object
     * @param {Object} options
     * @api private
     */
    packet(packet, [Map opts = const {}]){
        var self = this;

        // this writes to the actual connection
        writeToEngine(encodedPackets) {
            if (opts['volatile'] && !self.conn.transport.writable) return;
            for (var i = 0; i < encodedPackets.length; i++) {
                self.conn.write(encodedPackets[i], { 'compress': opts['compress'] });
            }
        }

        if ('open' == this.conn.readyState) {
            _logger.info('writing packet $packet');
            if (!opts['preEncoded']) { // not broadcasting, need to encode
                this.encoder.encode(packet, (encodedPackets) { // encode, then write results to engine
                    writeToEngine(encodedPackets);
                });
            } else { // a broadcast pre-encodes a packet
                writeToEngine(packet);
            }
        } else {
            _logger.info('ignoring packet write $packet');
        }
    }

    /**
     * Called with incoming transport data.
     *
     * @api private
     */
    ondata(data) {
        // try/catch is needed for protocol violations (GH-1880)
        try {
            this.decoder.add(data);
        } catch(e) {
            this.onerror(e);
        }
    }

    /**
     * Called when parser fully decodes a packet.
     *
     * @api private
     */
    ondecoded(packet) {
        if (parser.CONNECT == packet.type) {
            this.connect(packet.nsp);
        } else {
            var socket = this.nsps[packet.nsp];
            if (socket) {
                socket.onpacket(packet);
            } else {
                _logger.info('no socket for namespace packet.nsp');
            }
        }
    }

    /**
     * Handles an error.
     *
     * @param {Objcet} error object
     * @api private
     */
    onerror(err) {
        this.sockets.forEach((socket){
            socket.onerror(err);
        });
        this.onclose('client error');
    }

    /**
     * Called upon transport close.
     *
     * @param {String} reason
     * @api private
     */
    onclose(reason) {
        _logger.info('client close with reason $reason');

        // ignore a potential subsequent `close` event
        this.destroy();

        // `nsps` and `sockets` are cleaned up seamlessly
        var socket;
        this.sockets.forEach((socket) {
            socket.onclose(reason);
        });
        this.sockets.clear();
        this.decoder.destroy(); // clean up decoder
    }

    /**
     * Cleans up event listeners.
     *
     * @api private
     */
    destroy (){
        this.conn.removeListener('data', this.ondata);
        this.conn.removeListener('error', this.onerror);
        this.conn.removeListener('close', this.onclose);
        this.decoder.removeListener('decoded', this.ondecoded);
    }
}
