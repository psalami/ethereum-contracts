/**
 * Created by psalami on 3/6/15.
 */

var web3 = require('ethereum.js');
var fs = require('fs');


var RANDOM_MIN = 10;
var RANDOM_MAX = 12;
var USD_IN_ETHER = 10;

var args = process.argv.slice(2);
var printHelp = function(){
    console.log("usage: price-feeder.js [feed] [address] [abi]");
    console.log("feed may be one of: 'gold', 'random'");
}

if(args.length < 3){
    printHelp();
    process.exit(1);
}

var feed = args[0];
var address = args[1];
var abiPath = args[2];

if(feed == "help"){
    printHelp();
    process.exit(0);
}

web3.setProvider(new web3.providers.HttpSyncProvider('http://127.0.0.1:8082'));

//first, check to make sure that there is actually a contract at the specified address
var result = web3.eth.getData(address);
if(!web3.toAscii(result)){
    console.log("there is no contract at the specified address");
    process.exit(0);
}

//if the contract exists, create an instance from the abi
var abi = JSON.parse(fs.readFileSync(abiPath, {encoding: "utf8"}));
var OracleContract = web3.eth.contract(abi);
var oracle = new OracleContract(address);


var getRandomPrice = function(){
    var priceUsd = Math.random() * (RANDOM_MAX - RANDOM_MIN) + RANDOM_MIN;
    var priceWei = web3.toWei(priceUsd * USD_IN_ETHER, "ether");
    return priceWei;
}

var getGoldPrice = function(){
    return 2;
}

var feedOracle = function(){
    var price = null;
    if(feed == "random"){
        price = getRandomPrice();
    } else if(feed == "gold") {
        price = getGoldPrice();
    } else {
        console.log("invalid feed type: " + feed);
    }
    console.log("---");
    console.log("previous oracle price: " + oracle.call().getPrice());
    console.log("setting oracle price to " + price);
    oracle.sendTransaction({gas:50000}).setPrice(price);

}
feedOracle();
web3.eth.filter('chain').watch(function(res){
    feedOracle();
});


