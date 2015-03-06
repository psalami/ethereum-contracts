contract BitcoinPriceOracle {

    //this oracle returns the price (in wei) of the asset covered by this oracle (1 BTC)
    function getPrice() returns (int price) {
        return 2000000000000000000000;
    }
}