pragma solidity =0.6.0;

contract Registration {
    
    address payable GPO;
    uint constant manufacuterFee=1;
    uint constant HealthProviderPFee=1;
    mapping(address=>bool) manufacturers;
    mapping(address=>bool) distributors;
    mapping(address=>bool) healthproviders;
    
    
    event ManufacturerRegistered(address manufactuer);
    event DistributorRegistered(address manufactuer);
    event HealthProviderRegistered(address manufactuer);

    modifier onlyGPO{
      require(msg.sender == GPO,
      "Sender not authorized."
      );
      _;
    }   
    
    constructor() public{
        GPO=msg.sender;
    }
    
    function regsiterManuf() public payable{
        require(!manufacturers[msg.sender] && !distributors[msg.sender] && !healthproviders[msg.sender],
        "Address already used");
        require(msg.value>=manufacuterFee,
        "Administration fees insufficient");
        
        manufacturers[msg.sender]=true;
        emit ManufacturerRegistered(msg.sender);
    }
    
    function regsiterDist(address d) public onlyGPO{
        require(!manufacturers[d] && !distributors[d] && !healthproviders[d],
        "Address already used");
        
        distributors[d]=true;
        emit DistributorRegistered(d);
    }
    
    function regsiterHP() public payable{
        require(!manufacturers[msg.sender] && !distributors[msg.sender] && !healthproviders[msg.sender],
        "Address already used");
        require(msg.value>=HealthProviderPFee,
        "Administration fees insufficient");

        healthproviders[msg.sender]=true;
        emit HealthProviderRegistered(msg.sender);

    }
    
    function manufacturerExists(address m) public view returns(bool){
        return manufacturers[m];
    }

    function distributorExists(address d) public view returns(bool){
        return distributors[d];
    }
    
    function HPExists(address h) public view returns(bool){
        return healthproviders[h];
    }
    
    function isGPO(address payable g) public view returns(bool){
        return (g==GPO);
    }
    
    
}

contract PurchaseNegotiation{
    Registration registrationContract;
    
    enum status{
        NewContract,
        ManufacturerConfirmed,
        GPOConfirmed,
        ContractRejected,
        ContractClosed
    }
    
    struct contractType{
        address manufacturer;
        address distributor;
        uint productID;
        uint quantity;
        uint price;
        status orderStatus;
    }
    
    mapping(bytes32=>contractType) contracts;
    
    event NewContractPublished(bytes32 contractAddress, uint quantityOrdered, address manufacturer, uint priceRequested);

    event PriceNegotiation(bytes32 contractAddress, uint newPrice);

    event ContractRejected(bytes32 contractAddress);
    
    event ContractConfirmed(bytes32 contractAddress, uint quantity, address manufacturer, uint price);
    
    event ContractClosed(bytes32 contractAddress);
    
    event DistributorAssigned(bytes32 contractAddress, address distributor);

    event DeliveredToDistributor(bytes32 contractAddress, address distributor);


    modifier onlyGPO{
      require(registrationContract.isGPO(msg.sender),
      "Sender not authorized."
      );
      _;
    }   
    
    modifier onlyManufacturer{
      require(registrationContract.manufacturerExists(msg.sender),
      "Sender not authorized."
      );
      _;
    }   
    
    constructor(address registrationAddress)public {
        registrationContract=Registration(registrationAddress);
        
    }
    
    function newContract(uint productID, uint quantity, address manufacturer, uint price) public onlyGPO {
        require(registrationContract.manufacturerExists(manufacturer),
        "Manufacturer address not recognized."
        );

        bytes32 temp=keccak256(abi.encodePacked(msg.sender,now,address(this),productID));
        contracts[temp]=contractType(manufacturer,address(0),productID,quantity,price,status.NewContract);
        
        emit NewContractPublished(temp, quantity, manufacturer, price);

    }
    
    function negotiateContract(bytes32 contractAddress, uint newPrice) public onlyManufacturer{
        require(contracts[contractAddress].orderStatus==status.NewContract,
        "Contract not available for price negotiation."
        );

        if(contracts[contractAddress].price!=newPrice){
            contracts[contractAddress].price=newPrice;
            emit PriceNegotiation(contractAddress, newPrice);
        }
        
        contracts[contractAddress].orderStatus=status.ManufacturerConfirmed;

    }
    
    function rejectContract(bytes32 contractAddress) public onlyManufacturer{
        require(contracts[contractAddress].orderStatus==status.NewContract,
        "Contract not available for price negotiation."
        );
        
        contracts[contractAddress].orderStatus=status.ContractRejected;
        emit ContractRejected(contractAddress);
    }
    
    function confirmContract(bytes32 contractAddress) public onlyGPO {
        require(contracts[contractAddress].orderStatus==status.ManufacturerConfirmed,
        "Manufacturer did not accept the contract."
        );
        
        contracts[contractAddress].orderStatus=status.GPOConfirmed;
        emit ContractConfirmed(contractAddress, contracts[contractAddress].quantity, contracts[contractAddress].manufacturer, contracts[contractAddress].price);
        

    }
    
    function assignDistributor(bytes32 contractAddress, address distributor) public onlyGPO{
        contracts[contractAddress].distributor=distributor;
        emit DistributorAssigned(contractAddress, distributor);
    }
    
    function deliverToDistributor(bytes32 contractAddress, address distributor) public onlyGPO{
        emit DeliveredToDistributor(contractAddress, distributor);
    }
    
    function closeContract(bytes32 contractAddress) public onlyGPO {
        require(contracts[contractAddress].orderStatus==status.GPOConfirmed,
        "Contract not confirmed."
        );
        
        contracts[contractAddress].orderStatus=status.ContractClosed;
        emit ContractClosed(contractAddress);

    }
} 

contract PurchaseOrders{
    Registration registrationContract;
    
    struct PO_type{
        address healthProvider;
        address distributor;
        bool delivered;
    }
    
    mapping(uint=>PO_type) POs;
    
    modifier onlyDistributor{
      require(registrationContract.distributorExists(msg.sender),
      "Sender not authorized."
      );
      _;
    }   
    
    modifier onlyHP{
      require(registrationContract.HPExists(msg.sender),
      "Sender not authorized."
      );
      _;
    }   


    constructor(address registrationAddress)public {
        registrationContract=Registration(registrationAddress);
    }
    
    event POsubmitted(uint POnumber, address healthProvider, address distributor);
    event orderDelivered(uint POnumber);
    
    function submitPO(uint POnumber, address distributor) public onlyHP{
        POs[POnumber]=PO_type(msg.sender,distributor,false);
        emit POsubmitted(POnumber,msg.sender, distributor);

    }
    
    function deliverOrder(uint POnumber)public onlyDistributor{
        POs[POnumber].delivered=true;
        emit orderDelivered(POnumber);

    }
} 

contract RebatesSettelment{
    Registration registrationContract;
    
    mapping(bytes32=>uint) rebateRequests;
    
    modifier onlyDistributor{
      require(registrationContract.distributorExists(msg.sender),
      "Sender not authorized."
      );
      _;
    }   
    
    modifier onlyManufacturer{
      require(registrationContract.manufacturerExists(msg.sender),
      "Sender not authorized."
      );
      _;
    }   
    
    event RequestSubmitted(bytes32 contractAddress, address distributor, address manufacturer, uint amountRequested);
    event RequestApproved(bytes32 contractAddress);
    
    constructor(address registrationAddress)public {
        registrationContract=Registration(registrationAddress);
        
    }
    
    
    function submitRebateRequest(bytes32 contractAddress, uint amount, address manufacturer) public onlyDistributor{
        require(registrationContract.manufacturerExists(manufacturer),
        "Manufacturer address not authorized."
        );
        rebateRequests[contractAddress]=amount;
        emit RequestSubmitted(contractAddress,msg.sender,manufacturer,amount);
    }
    
    function approveRebateRequest(bytes32 contractAddress, address payable manufacturer) public payable onlyManufacturer{
        require(rebateRequests[contractAddress]>0,
        "Rebate request not submitted for this contract."
        );
        require(msg.value>=rebateRequests[contractAddress],
        "Transferred amount insufficient."
        );
        
        emit RequestApproved(contractAddress);
        manufacturer.transfer(msg.value);
        
    }
} 

contract LoyaltyRebates{
    Registration registrationContract;
    
    modifier onlyGPO{
      require(registrationContract.isGPO(msg.sender),
      "Sender not authorized."
      );
      _;
    }   
    
    constructor(address registrationAddress)public {
        registrationContract=Registration(registrationAddress);
        
    }
    
    function sendLoyaltyRebate(address payable healthProvider) payable public onlyGPO{
      require(registrationContract.HPExists(healthProvider),
      "Health provider address not recognized."
      );   
      healthProvider.transfer(msg.value);
    }

    
} 
