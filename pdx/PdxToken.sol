pragma solidity =0.6.6;

import '../libraries/EnumerableSet.sol';
import './DelegateERC20.sol';
import './Ownable.sol';


contract PdxToken is DelegateERC20, Ownable {
   uint256 private constant maxSupply =    1000000000 * 1e18; 
   uint256 private constant miningSupply =  800000000 * 1e18;
   uint256 private constant groupSupply =   100000000 * 1e18;
   uint256 private constant initSupply =     70000000 * 1e18;
   uint256 private constant marketSupply =   30000000 * 1e18;
   uint256 private constant oneMonth =  876000;
   
   uint256 private leftMiningSupply =       800000000 * 1e18;
   uint256 private leftGroupSupply =        100000000 * 1e18;
   uint256 private leftMarketSupply =        30000000 * 1e18;
   
   address public groupAddress;
   address public marketAddress;
   
   uint256 public startBlock;
   
   bool public started = false;
   
   uint256 public groupCurrentBlock;
   
   uint256 public marketCurrentBlock;
                                  
   uint256 public groupPerBlock = 4756468797564700000;

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _minters;

    constructor() public ERC20("Pdx Token", "PDX"){
        _mint(msg.sender, initSupply);
    }
    
    function setAddresses(address _groupAddress,address _marketAddress) public onlyOwner returns (bool)  {
        groupAddress =_groupAddress;
        marketAddress = _marketAddress;
    }
    
    function setStartBlock(uint256 _block) public onlyOwner {
        startBlock = _block;
        groupCurrentBlock = _block.add(oneMonth);
        marketCurrentBlock = _block.add(oneMonth.mul(12));
        started = true;
    }
    
    
    function mintGroup()public onlyOwner {
        
        require(started,"token mint not start.");
        
        require(leftGroupSupply>0,"mint end.");
        
        uint256 _thisBlock = block.number;
        
        if(_thisBlock<=groupCurrentBlock){
            return;
        }
        
        require(groupAddress != address(0),"pdx: groupAddress empty."); 

        uint256 _amount = (_thisBlock-groupCurrentBlock)*groupPerBlock;
        
        require(_amount.add(totalSupply()) <= maxSupply,"pdx: out of max.");
        
        groupCurrentBlock = _thisBlock;
        
        if(leftGroupSupply<_amount){
            _amount = leftGroupSupply;
        }
        
        leftGroupSupply = leftGroupSupply - _amount;
        
        _mint(groupAddress,_amount);
    }
    
    function mintMarket() public onlyOwner {
        
        require(started,"token mint not start.");
        
        require(leftMarketSupply>0,"mint end.");
        
        uint256 _thisBlock = block.number;
        
        if(_thisBlock<=marketCurrentBlock){
            return;
        }
        
        uint256 _amount = leftMarketSupply;
        
        require(_amount.add(totalSupply()) <= maxSupply,"pdx: out of max.");
        
        require(marketAddress != address(0),"pdx: marketAddress empty."); 
        
        marketCurrentBlock = _thisBlock;
        
        leftMarketSupply = leftMarketSupply - _amount;
        
        _mint(marketAddress,_amount);
    }


    // mint with max supply
    function mint(address _to, uint256 _amount) public onlyMinter returns (bool) {
        if(_amount>leftMiningSupply){
            _amount = leftMiningSupply;
        }
        if(_amount<=0){
            return false;
        }
        
        leftMiningSupply = leftMiningSupply - _amount;
        
        if (_amount.add(totalSupply()) > maxSupply) {
            return false;
        }
        _mint(_to, _amount);
        return true;
    }

    function addMinter(address _addMinter) public onlyOwner returns (bool) {
        require(_addMinter != address(0), "DexToken: _addMinter is the zero address");
        return EnumerableSet.add(_minters, _addMinter);
    }

    function delMinter(address _delMinter) public onlyOwner returns (bool) {
        require(_delMinter != address(0), "DexToken: _delMinter is the zero address");
        return EnumerableSet.remove(_minters, _delMinter);
    }

    function getMinterLength() public view returns (uint256) {
        return EnumerableSet.length(_minters);
    }

    function isMinter(address account) public view returns (bool) {
        return EnumerableSet.contains(_minters, account);
    }

    function getMinter(uint256 _index) public view onlyOwner returns (address){
        require(_index <= getMinterLength() - 1, "DexToken: index out of bounds");
        return EnumerableSet.at(_minters, _index);
    }

    // modifier for mint function
    modifier onlyMinter() {
        require(isMinter(msg.sender), "caller is not the minter");
        _;
    }

}