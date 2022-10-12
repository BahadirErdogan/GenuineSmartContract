// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiSignature {
    
    address mainOwner; // --> First user who creates the wallet
    address[] walletowners;
    uint limit; // --> Approve limit
    uint depositId = 0;
    uint withdrawalId = 0;
    uint transferId = 0;
    
    constructor() {
        
        mainOwner = msg.sender; //set main owner who launch the contrat      
        walletowners.push(mainOwner); //add main owner to walletowners array
        limit = walletowners.length - 1; //Every owner should approve except owner of the transaction
                                        // We can define in different way like %51, %60 of owners etc.
    }
    
    mapping(address => uint) balance; // key --> adress, value --> uint(amount)
    // double mapping approvals[msg.sender[id] = true/false 
    mapping(address => mapping(uint => bool)) approvals; 
    
    struct Transfer {
        
        address sender;
        address payable receiver;
        uint amount;
        uint id;
        uint approvals; // --> We need number of approvals for a certain transfer. (MultiSignWallet)
        uint timeOfTransaction;
    }
    
    Transfer[] transferRequests; // An array to store all instances of transfer requests
    
    event walletOwnerAdded(address addedBy, address ownerAdded, uint timeOfTransaction);
    event walletOwnerRemoved(address removedBy, address ownerRemoved, uint timeOfTransaction);
    event fundsDeposited(address sender, uint amount, uint depositId, uint timeOfTransaction);
    event fundsWithdrawed(address sender, uint amount, uint withdrawalId, uint timeOfTransaction);
    event transferCreated(address sender, address receiver, uint amount, uint id, uint approvals, uint timeOfTransaction);
    event transferCancelled(address sender, address receiver, uint amount, uint id, uint approvals, uint timeOfTransaction);
    event transferApproved(address sender, address receiver, uint amount, uint id, uint approvals, uint timeOfTransaction);
    event fundsTransfered(address sender, address receiver, uint amount, uint id, uint approvals, uint timeOfTransaction);
    
    //when we use this modifier on a function --> only wallet owner can call that function
    modifier onlyowners() {
        
       bool isOwner = false;
       for (uint i = 0; i< walletowners.length; i++) {
           
           if (walletowners[i] == msg.sender) {
               
               isOwner = true;
               break;
           }
       }
       
       require(isOwner == true, "Only wallet owners can call this function");
       _;
        
    }
   
    //Function return an array (all wallet owners)
    function getWalletOners() public view returns(address[] memory) {
        
        return walletowners;
    }
    
    //Function add an owner(address) to walletowners array
    function addWalletOwner(address owner) public onlyowners {

        //check is owner already exist in array
       for (uint i = 0; i < walletowners.length; i++) {
           
           if(walletowners[i] == owner) {
               
               revert("Cannot add duplicate owners");
           }
       }
        
        walletowners.push(owner);
        limit = walletowners.length - 1; // Redefine of the size of the limit, because number of the owner is changed
        
        emit walletOwnerAdded(msg.sender, owner, block.timestamp);
    }
    
    //Function remove an owner(address) from walletowners array
    function removeWalletOwner(address owner) public onlyowners {

        bool hasBeenFound = false;
        uint ownerIndex;
        for (uint i = 0; i < walletowners.length; i++) {
            
            if(walletowners[i] == owner) {
                
                hasBeenFound = true; // --> if owner exist in array
                ownerIndex = i; // --> index number of owner
                break;
            }
        }
        
        require(hasBeenFound == true, "Wallet owner not detected");
        
        //move owner to the end in the array and remove last element with pop method
        walletowners[ownerIndex] = walletowners[walletowners.length - 1];
        walletowners.pop();
        limit = walletowners.length - 1; // Redefine of the size of the limit, because number of the owner is changed
        
         emit walletOwnerRemoved(msg.sender, owner, block.timestamp);
       
    }
    
    //There is no amount pareameter. Because amount of ether stored in msg.value
    function deposit() public payable onlyowners {
        
        //Deposit must be greater then "0"
        require(balance[msg.sender] >= 0, "Cannot deposiit a value of 0");
        
        balance[msg.sender] = msg.value;
        
        emit fundsDeposited(msg.sender, msg.value, depositId, block.timestamp);
        depositId++;
        
    } 
    
    //Takes amount(uint) that to withdraw as a argument
    function withdraw(uint amount) public onlyowners {
        
        //balance need to be sufficient
        require(balance[msg.sender] >= amount);
        
        balance[msg.sender] -= amount;
        
        payable(msg.sender).transfer(amount);
        
        emit fundsWithdrawed(msg.sender, amount, withdrawalId, block.timestamp);
         withdrawalId++;
        
    }
    
    // It takes arguments receiver address and amount of the ether
    function createTransferRequest(address payable receiver, uint amount) public onlyowners {
        
        //balance must be greater then amount of the transfer request
        require(balance[msg.sender] >= amount, "Insufficent funds to create a transfer");
        
        for (uint i = 0; i < walletowners.length; i++) {
            
            require(walletowners[i] != receiver, "Cannot transfer funds within the wallet");
        }
        
        //Decrease sender balance and push the request to Transfer Array with its attributes
        balance[msg.sender] -= amount;
        transferRequests.push(Transfer(msg.sender, receiver, amount, transferId, 0, block.timestamp));
        transferId++;
        emit transferCreated(msg.sender, receiver, amount, transferId, 0, block.timestamp);
    }
    
    //For canceling transfer. Functions takes id of transfer request as an argument
    function cancelTransferRequest(uint id) public onlyowners {
        
        bool hasBeenFound = false;
        uint transferIndex = 0;
        for (uint i = 0; i < transferRequests.length; i++) {
            
            if(transferRequests[i].id == id) {
                
                hasBeenFound = true; // if exist break for loop
                break;
               
            }
            
             transferIndex++; // --> index of transfer
        }
        
        //Transfer must exist and msg.sender must be transfer creator
        require(transferRequests[transferIndex].sender == msg.sender, "Only the transfer creator can cancel");
        require(hasBeenFound, "Transfer request does not exist");
        
        //Increase amount of sender balance as request amount
        balance[msg.sender] += transferRequests[transferIndex].amount;
        
        //move transfer request to the end in the array and remove last element with pop method
        transferRequests[transferIndex] = transferRequests[transferRequests.length - 1];
        
        emit transferCancelled(msg.sender, transferRequests[transferIndex].receiver, transferRequests[transferIndex].amount, transferRequests[transferIndex].id, transferRequests[transferIndex].approvals, transferRequests[transferIndex].timeOfTransaction);
        transferRequests.pop();
    }
    
    //For approve transfer request. It takes transfer request id as an argument
    function approveTransferRequest(uint id) public onlyowners {
        
        bool hasBeenFound = false;
        uint transferIndex = 0;
        for (uint i = 0; i < transferRequests.length; i++) {
            
            if(transferRequests[i].id == id) {
                
                hasBeenFound = true;
                break;
                
            }
            
             transferIndex++;
        }

        //Transfer must exist
        //Is the address of the owner does has he/she approved this transaction id before. Yes or No
        //Transfer creator cannot approve the transfer!!
        require(hasBeenFound, "Transfer request does not exist");
        require(approvals[msg.sender][id] == false, "Cannot approve the same transfer twice");
        require(transferRequests[transferIndex].sender != msg.sender, "Cannot approve your own transfer request!");
        
        approvals[msg.sender][id] = true;
        transferRequests[transferIndex].approvals++;
        
        emit transferApproved(msg.sender, transferRequests[transferIndex].receiver, transferRequests[transferIndex].amount, transferRequests[transferIndex].id, transferRequests[transferIndex].approvals, transferRequests[transferIndex].timeOfTransaction);
        
        //Limit is number of approve limit. If we have enough approval then call transferFunds function
        if (transferRequests[transferIndex].approvals == limit) {
            
            transferFunds(transferIndex);
        }
    }
    
    //It is private because we call this function only in approveTransferRequest function
    function transferFunds(uint id) private {
        
        //Increase receiver balance as much as transfer amount
        balance[transferRequests[id].receiver] += transferRequests[id].amount;
        transferRequests[id].receiver.transfer(transferRequests[id].amount);
        
        emit fundsTransfered(msg.sender, transferRequests[id].receiver, transferRequests[id].amount, transferRequests[id].id, transferRequests[id].approvals, transferRequests[id].timeOfTransaction);
        
        //Delete transferRequest from transferRequests array
        transferRequests[id] = transferRequests[transferRequests.length - 1];
        transferRequests.pop();
    }
    
    //Function return approvals of message.sender for a given transfer id
    function getApprovals(uint id) public view returns(bool) {
        
        return approvals[msg.sender][id];
    }
    
    //Function return an array (Transfer Requests)
    function getTransferRequests() public view returns(Transfer[] memory) {
        
        return transferRequests;
    }
    
    //balance mapping allows us to keep track of the distrubitions of funds among all of the owners in the wallet
    function getBalance() public view returns(uint) {
        
        return balance[msg.sender];
    }
    
    //Function returns limit
    function getApprovalLimit() public view returns (uint) {
        
        return limit;
    }
    
    //Contract balance
     function getContractBalance() public view returns(uint) {
        
        return address(this).balance;
    }

}