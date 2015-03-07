contract PriceOracle {

    address creator;
    int price;

    function PriceOracle(){
        creator = msg.sender;
    }

    function setPrice(int newPrice) {
        if(msg.sender != creator){
            return;
        }

        price = newPrice;
    }

    //this oracle returns the price (in wei) of the asset covered by this oracle
    function getPrice() returns (int) {
        return price;
    }

    function getCreator() returns(address){
        return creator;
    }
}