pragma solidity =0.6.6;

import '../interfaces/IERC20.sol';
import '../libraries/SafeMath2.sol';

contract ERC20 is IERC20 {
    using SafeMath2 for uint;

    string public override  name ;
    string public override  symbol ;
    uint8 public override  decimals ;
    uint  public override totalSupply ;
    mapping(address => uint) public override balanceOf;
    mapping(address => mapping(address => uint)) public allowances;

    mapping(address => uint) public nonces;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor(uint8 _decimals,uint256 _initialSupply,
        string memory _tokenName,
        string memory _tokenSymbol) public {
        name = _tokenName;
        symbol = _tokenSymbol;
        totalSupply = _initialSupply;
        decimals = _decimals;
        _mint(msg.sender, totalSupply);
    }
    
    function allowance(address owner, address spender) override public view  returns (uint256) {
        return allowances[owner][spender];
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value)override external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value)override external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value)override external returns (bool) {
        if (allowances[from][msg.sender] != uint(-1)) {
            allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }
}