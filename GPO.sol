pragma solidity =0.6.0;

contract Registration {
    
    address payable GPO;
    uint constant manufacuterFee=1;
    uint constant HealthProviderPFee=1;
    mapping(address=>bool) manufacturers;
    mapping(address=>bool) distributors;
    mapping(address=>bool) healthproviders;
    
    
    event ManufacturerRegistered(address manufactuer);
    event DistributorRegistered(address distributor);
    event HealthProviderRegistered(address healthProvider);

    modifier onlyGPO{
      require(msg.sender == GPO,
      "Sender not authorized."
      );
      _;
    }   
    
    constructor() public{
        GPO=msg.sender;
    }
    
    function registerManufacturer() public payable{
        require(!manufacturers[msg.sender] && !distributors[msg.sender] && !healthproviders[msg.sender],
        "Address already used");
        require(msg.value>=manufacuterFee,
        "Admission fee insufficient");
        
        manufacturers[msg.sender]=true;
        emit ManufacturerRegistered(msg.sender);
    }
    
    function registerDistributor(address d) public onlyGPO{
        require(!manufacturers[d] && !distributors[d] && !healthproviders[d],
        "Address already used");
        
        distributors[d]=true;
        emit DistributorRegistered(d);
    }
    
    function registerProvider() public payable{
        require(!manufacturers[msg.sender] && !distributors[msg.sender] && !healthproviders[msg.sender],
        "Address already used");
        require(msg.value>=HealthProviderPFee,
        "Admission fee insufficient");

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
    uint public contractAddresses;
    enum status{
        NewContract,
        Negotiating,
        PriceConfirmed,
        PriceRejected,
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
    
    mapping(uint=>contractType) public contracts;
    
    event NewContractPublished(uint contractAddress, uint quantityOrdered, address manufacturer);

    event PriceNegotiation(uint contractAddress, uint newPrice);

    event ContractConfirmed(uint contractAddress, uint quantity, address manufacturer, uint price);
    
    event ContractClosed(uint contractAddress);

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
        contractAddresses=uint(keccak256(abi.encodePacked(msg.sender,now,address(this))));

    }
    
    function newContract(uint productID, uint quantity, address manufacturer) public onlyGPO {
        require(registrationContract.manufacturerExists(manufacturer),
        "Manufacturer address not recognized."
        );
        contractAddresses++;
        contracts[contractAddresses]=contractType(manufacturer,address(0),productID,quantity,0,status.NewContract);
        
        emit NewContractPublished(contractAddresses, quantity, manufacturer);

    }
    
    function negotiateContract(uint contractAddress, uint newPrice) public onlyManufacturer{
        require(contracts[contractAddress].orderStatus==status.NewContract  || contracts[contractAddress].orderStatus==status.PriceRejected,
        "Contract not available for price negotiation."
        );
        require(contracts[contractAddress].manufacturer==msg.sender,
        "Manufacturer not authorized"    
        );
        emit PriceNegotiation(contractAddress, newPrice);
        contracts[contractAddress].price=newPrice;
        contracts[contractAddress].orderStatus=status.Negotiating;

    }

    function contractStatus(uint contractAddress, bool accepted) public onlyGPO{
        require(contracts[contractAddress].orderStatus==status.Negotiating,
        "Contract not available for price negotiation."
        );
        if(accepted){
            contracts[contractAddress].orderStatus=status.PriceConfirmed;
        emit ContractConfirmed(contractAddress, contracts[contractAddress].quantity, contracts[contractAddress].manufacturer, contracts[contractAddress].price);
        }
        else{
            contracts[contractAddress].orderStatus=status.PriceRejected;
        }
    }
    
    
    function assignDistributor(uint contractAddress, address distributor) public onlyGPO{
        require(contracts[contractAddress].orderStatus==status.PriceConfirmed,
        "Contract not confirmed."
        );
        require(registrationContract.distributorExists(distributor),
        "Distributor adaddress not valid"
        );
        contracts[contractAddress].distributor=distributor;
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
    event OrderDelivered(uint POnumber);
    
    function submitPO(uint POnumber, address distributor) public onlyHP{
        POs[POnumber]=PO_type(msg.sender,distributor,false);
        emit POsubmitted(POnumber,msg.sender, distributor);

    }
    
    function deliverStatus(uint POnumber)public onlyDistributor{
        require(POs[POnumber].distributor==msg.sender,
        "Distributor not authorized"
        );
        
        POs[POnumber].delivered=true;
        emit OrderDelivered(POnumber);

    }
} 

contract RebatesSettelment{
    Registration registrationContract;
    
    mapping(uint=>uint) rebateRequests;
    
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
    
    event RequestSubmitted(uint contractAddress, address distributor, address manufacturer, uint amountRequested);
    event RequestApproved(uint contractAddress);
    
    constructor(address registrationAddress)public {
        registrationContract=Registration(registrationAddress);
        
    }
    
    
    function submitRebateRequest(uint contractAddress, uint amount, address manufacturer) public onlyDistributor{
        require(registrationContract.manufacturerExists(manufacturer),
        "Manufacturer address not authorized."
        );
        rebateRequests[contractAddress]=amount;
        emit RequestSubmitted(contractAddress,msg.sender,manufacturer,amount);
    }
    
    
    function approveRebateRequest(uint contractAddress, address payable distributor) public payable onlyManufacturer{
        require(rebateRequests[contractAddress]>0,
        "Rebate request not submitted for this contract."
        );
        require(msg.value>=rebateRequests[contractAddress],
        "Transferred amount insufficient."
        );
        rebateRequests[contractAddress]=0;
        emit RequestApproved(contractAddress);
        distributor.transfer(msg.value);
        
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
