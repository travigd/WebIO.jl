function setup_blink_comm(procId) {
    if (Blink.sock) {
        WebIO.sendCallbacks[procId] = function (msg) {
            Blink.msg("webio", msg);
        }
        WebIO.triggerConnected();
    } else {
        console.error("Blink not connected")
    }

    Blink.handlers.webio = function (msg) {
        WebIO.dispatch(msg.data);
    };
}
