console.log('I AM EXECUTED');

var socketttss = {on : function(arg, callback) { console.log("pseudo socket on called " + arg);  if('connected' == arg) callback()} };

io = {
	version: "none",
	protocol: 1,
	transport: ["empty1", "empty2", "empty3", "empty4", "empty5"],
	j: [],
	EventEmitter: function() { console.log("pseudo io EventEmitter called");},
	JSON: {},
	sockets: socketttss,
	Socket: function() { console.log("pseudo io Socket called") },
	SocketNamespace: function() { console.log("pseudo io SocketNamespace called") },
	Transport:  function() { console.log("pseudo io Transport called") },
	connect:  function() { console.log("pseudo io connect called"); return socketttss;},
	parser:  {},
	protocol: 1,
	util: {},
	__proto__: {}
	};

