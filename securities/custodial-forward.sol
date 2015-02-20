contract BitcoinPriceOracle {

    //this oracle returns the price (in wei) of the
    //
    function getPrice() returns (uint price) {
        return 2000000000000000000000;
    }
}

contract CustodialForward {
    // This contract represents a forward contract that takes custody of collateral form both parties
    // for the term of the contract. The underlying asset can be anything, including a fractional share
    // of another asset.
    // This contract will depend on a trusted oracle (or arbiter) to provide the price of the underlying asset
    // upon contract expiration. The address of the oracle will be hard-coded into this contract.
    // Both parties are expected to inspect the source code before entering into the contract
    // and thereby certify their trust in the oracle.
    // Upon expiration of the contract, the oracle is queried for the price of the underlying
    // asset, and a settlement amount is computed by the contract. The contract is settled in cash (ether)
    //
    // A forward contract is similar to a futures contract that can be
    // customized to suit the needs of the parties. This file is intended as a template upon which to
    // build more customized contracts.

    unit64 expirationDate;
    unit64 openDate;
    uint8 marginPercent;


    address creator;
    //the user who currently owns the contract (the seller before the contract is sold, the buyer after it is sold)
    //we should revisit the concept of owner to see if it makes sense
    address owner;
    address seller;
    uint sellerBalance; //the margin posted by seller + settlement amount (added after close); user may post more than minimum margin
    unit buyerBalance; //the margin posted by seller + settlement amount (added after close); user may post more than minimum margin
    address underlyingPriceOracleAddress = "";
    string underlyingAssetDescription = "bitcoin"; //the underlying (whole) asset (i.e. BTC)
    string underlyingAssetUnitDescription = "1/1000 of 1"; //describes how a unit of this contract is derived from the underlying
    string underlyingAssetFraction = 1000; //used to compute a unit of this contract as a fraction of the underlying
    string underlyingAssetMultiple = 1; //used to compute a unit of this contract as a multiple of the underlying

    unit amount; // the number of units that this contract represents (i.e. 100 units of 1/1000 BTC)
    contract underlyingPriceOracle = BitcoinPriceOracle(underlyingPriceOracleAddress);

    bool isAvailable = false; //contract is not available for purchase until offered with sufficient margin by a seller

    /**
     * Creates a new forward contract. Requires customization of the number of units
     * that this contract represents and the expiration date. We could require that
     * those params should be hard-coded instead, or we could allow more parameters to
     * be configured here.
     *
     * @constructor
     */
    function CustodialForward(uint amount, uint64 expirationDate){
        creator = msg.sender;
        this.amount = amount;
        openDate = block.timestamp;
    }

    /**
     * Make this contract available for purchase; collateral from the seller is required.
     * We could require that this method should be called by the constructor.
     */
    function offer() returns (string success) {
        if(msg.value < computeMarginAmount()){
            //return funds to sender
            msg.sender.send(msg.value);
            return "insufficient margin posted";
        }
        //if the margin is sufficient, assign ownership to the sender who will become the seller
        owner = msg.sender;
        seller = msg.sender;
        isAvailable = true;
        return "contract offered successfully with collateral";

    }

    function buy() returns (string success) {
        if(!isAvailable){
            //return funds to sender
            msg.sender.send(msg.value);
            return "contract has not been offered for sale yet";
        }
        if(msg.value < computeMarginAmount()){
            //return funds to sender
            msg.sender.send(msg.value);
            return "insufficient margin posted";
        }
        //if the margin is sufficient, the buyer becomes the new contract holder and the contract is taken off the
        //market by setting its availability
        owner = msg.sender;
        isAvailable = false;
    }

    /**
     * Either current owner (buyer) or seller can call this method at or after the expiration date
     * in order to settle the contract. The contract will compute the settlement amount and return the
     * balance of the collateral plus settlement to the respective parties.
     */
    function close() returns (string success) {

    }

    function available() returns (bool isAvailable){
        return isAvailable;
    }

    /**
     * Computes the amount of margin that each party is required to post to enter into this contract.
     * The margin amount is a pre-defined percentage as derived from the current price of the underlying
     * (per the mutually agreed-upon oracle), to the price of a single unit of the contract and multiplying
     * by the number of units that this contract represents.
     *
     */
    function computeMarginAmount() private returns (unit margin) {
        return underlyingPriceOracle.getPrice() / underlyingAssetFraction * underlyingAssetMultiple * amount * marginPercent / 100;
    }









}