contract BitcoinPriceOracle {

    //this oracle returns the price (in wei) of the asset covered by this oracle (1 BTC)
    function getPrice() returns (int price) {
        return 2000000000000000000000;
    }
}

contract CollateralizedNDF {
    // This contract represents a particular type of forward contract known as a non-deliverable forward (NDF).
    // In an NDF, the difference between the contracted price and the prevailing market price of the underlying
    // at the time of contract expiration (in this case as provided by a trusted oracle)
    // is settled in cash (in this case Ether, represented in wei).
    //
    // Upon entering into the contract, the contract takes custody of collateral form both parties
    // for the term of the contract. The collateral is used to settle the balance of the parties' accounts upon
    // contract expiration. The underlying asset can be anything, including a fractional share
    // of a non-crypto asset, so long as there exists an oracle which is trusted by both parties to the contract and which
    // is capable of reporting the price of the underlying upon contract offering and settlement.
    //
    // The address of the trusted oracle will be hard-coded into this contract as submitted to the blockchain.
    // Both parties are expected to inspect the source code before entering into the contract
    // and thereby certify their trust in the oracle.
    // Upon expiration of the contract, the oracle is queried for the price of the underlying
    // asset, and a settlement amount is computed by the contract.
    // The contract is settled in cash (Ether, delivered to the addresses of the parties to the contract).
    //
    // A forward contract is similar to a futures contract that can be customized to suit the needs of the parties.
    // This file is intended as a template upon which to build more customized contracts (i.e. forwards with
    // more customized terms or CFDs).

    uint expirationDate;
    uint openDate;
    int8 marginPercent;


    address creator;
    //the user who currently owns the contract (the seller before the contract is sold, the buyer after it is sold)
    //we should revisit the concept of owner to see if it makes sense
    address owner;
    address seller;
    uint sellerBalance; //the margin posted by seller + settlement amount (added after close); user may post more than minimum margin
    uint buyerBalance; //the margin posted by seller + settlement amount (added after close); user may post more than minimum margin
    address underlyingPriceOracleAddress; //leave blank for now (oracle is defined here and has static output)
    string32 underlyingAssetDescription; //the underlying (whole) asset (i.e. BTC)
    string32 underlyingAssetUnitDescription; //describes how a unit of this contract is derived from the underlying
    int underlyingAssetFraction; //used to compute a unit of this contract as a fraction of the underlying
    int underlyingAssetMultiple; //used to compute a unit of this contract as a multiple of the underlying

    int amount; // the number of units that this contract represents (i.e. 100 units of 1/1000 BTC)
    BitcoinPriceOracle underlyingPriceOracle;
    int contractedPrice; //the price (in wei) at which the buyer of the contract agrees to purchase one unit upon contract expiration

    int buyerDefaultAmount; //amount (in wei) by which the buyer's margin balance is deficient of the settlement amount
    int sellerDefaultAmount; //amount (in wei) by which the seller's margin balance is deficient of the settlement amount

    bool isAvailable; //contract is not available for purchase until offered with sufficient margin by a seller
    bool isSettled; //set to true after the contract has been fully settled

    /**
     * Creates a new forward contract. Requires customization of the number of units
     * that this contract represents, the expiration date and the contracted price. We could require that
     * those params should be hard-coded in the constructor instead, or we could allow more parameters to
     * be configurable as constructor arguments.
     *
     * @constructor
     */
    function CustodialForward(int creationAmount, uint expirationDate, int creationContractedPrice){
        creator = msg.sender;
        amount = creationAmount;
        contractedPrice = creationContractedPrice;
        openDate = block.timestamp;

        //pre-defined values; note that these values should be modified prior to contract submission to the blockchain
        //to suit the needs of the parties to the trade
        underlyingPriceOracle = BitcoinPriceOracle(underlyingPriceOracleAddress);
        underlyingAssetDescription = "bitcoin";
        underlyingAssetUnitDescription = "1/1000 of 1";
        underlyingAssetFraction = 1000;
        underlyingAssetMultiple = 1;
        isAvailable = false;
        isSettled = false;
    }

    /**
     * Make this contract available for purchase; collateral from the seller is required.
     * We could require that this method should be called by the constructor.
     */
    function offer() returns (string32 success) {
        if(int(msg.value) < computeMarginAmount()){
            //return funds to sender
            msg.sender.send(msg.value);
            return "insufficient margin posted";
        }
        //if the margin is sufficient, assign ownership to the sender who will become the seller
        owner = msg.sender;
        seller = msg.sender;
        sellerBalance = msg.value;
        isAvailable = true;
        return "contract offered successfully";
    }

    /**
     * This method can be called by any who wishes to take the opposite side of the seller.
     * The caller must send sufficient ether with this method call to cover the required margin that must
     * be posted for this contract.
     */
    function buy() returns (string32) {
        if(!available()){
            //return funds to sender
            msg.sender.send(msg.value);
            return "contract not available";
        }
        if(int(msg.value) < computeMarginAmount()){
            //return funds to sender
            msg.sender.send(msg.value);
            return "insufficient margin posted";
        }
        //if the margin is sufficient, the buyer becomes the new contract holder and the contract is taken off the
        //market by setting its availability to false

        owner = msg.sender;
        buyerBalance = msg.value;
        isAvailable = false;
        openDate = block.timestamp;
    }

    /**
     * Either current owner (buyer) or seller can call this method at or after the expiration date
     * in order to settle the contract. The contract will compute the settlement amount and return the
     * balance of the collateral plus settlement to the respective parties.
     */
    function close() returns (string32 success) {
        if(available()){
            //if the contract is still on the market (or has already been settled), we cannot settle it
            return "contract not available";
        }
        if(block.timestamp < expirationDate){
            return "cannot close before expiration";
        }

        //adjust the balance of the buyer and seller based on the price of the underlying asset upon contract expiration
        int settlementAmount = computeSettlementAmount();
        int buyerBalance = buyerBalance  + settlementAmount;
        int sellerBalance = sellerBalance - settlementAmount;

        uint buyerBalanceUnsigned;
        uint sellerBalanceUnsigned;

        //capture amount of deficiencies if margins were insufficient
        if(buyerBalance < 0){
            buyerDefaultAmount = buyerBalance * -1;
            buyerBalance = 0;
            buyerBalanceUnsigned = 0;
        } else {
            buyerBalanceUnsigned = uint(buyerBalance);
        }

        if(sellerBalance < 0){
            sellerDefaultAmount = sellerBalance * -1;
            sellerBalance = 0;
            sellerBalanceUnsigned = 0;
        } else {
            sellerBalanceUnsigned = uint(sellerBalance);
        }

        //send the amounts owed to the respective parties to settle the contract
        owner.send(buyerBalanceUnsigned);
        seller.send(sellerBalanceUnsigned);


    }

    function computeSettlementAmount() private returns (int) {
        int contractPrice = contractedPrice / underlyingAssetFraction * underlyingAssetMultiple * amount;
        int currentContractValue = underlyingPriceOracle.getPrice() / underlyingAssetFraction * underlyingAssetMultiple * amount;
        return currentContractValue - contractPrice;


    }

    function available() returns (bool isAvailable){
        return isAvailable && !isSettled;
    }

    /**
     * Computes the amount of margin that each party is required to post to enter into this contract.
     * The margin amount is a pre-defined percentage as derived from the current price of the underlying
     * (per the mutually agreed-upon oracle), to the price of a single unit of the contract and multiplying
     * by the number of units that this contract represents.
     *
     */
    function computeMarginAmount() returns (int margin) {
        return underlyingPriceOracle.getPrice() / underlyingAssetFraction * underlyingAssetMultiple * amount * marginPercent / 100;
    }

}