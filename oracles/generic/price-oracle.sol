contract PriceOracle {

    address creator;
    int128 price;

    function PriceOracle(){
        creator = msg.sender;
    }

    function setPrice(int128 newPrice) {
        if(msg.sender != creator){
            return;
        }

        price = newPrice;
    }

    //this oracle returns the price (in wei) of the asset covered by this oracle
    function getPrice() returns (int128) {
        return price;
    }

}
