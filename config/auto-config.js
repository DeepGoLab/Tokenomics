const { RINKEBY_CONFIG, POLYGON_CONFIG } = require("./rinkeby-config.js");

exports.GetConfig = function (chainId) {
    var CONFIG = {}
    switch (chainId) {
        case "4":
            CONFIG = RINKEBY_CONFIG
            break;
        case "1337":
            CONFIG = POLYGON_CONFIG
            break;
    }
    return CONFIG
}
