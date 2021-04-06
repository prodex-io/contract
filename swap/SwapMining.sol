pragma solidity =0.6.6;

import '../interfaces/IERC20.sol';
import '../interfaces/IPdx.sol';
import '../interfaces/IFactory.sol';
import '../interfaces/IPair.sol';

import '../libraries/EnumerableSet.sol';
import '../libraries/SafeMath2.sol';
import '../interfaces/IOracle.sol';
import '../commons/Ownable.sol';


contract SwapMining is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _whitelist;

    // The block number when PDX mining starts.
    uint256 public startBlock;
    // Total allocation points
    uint256 public totalAllocPoint = 0;
    IOracle public oracle;
    // router address
    address public router;
    // factory address
    IFactory public factory;
    // pdx token address
    IPdx public pdx;
    // Calculate price based on HUSD
    address public targetToken;
    // pair corresponding pid
    mapping(address => uint256) public pairOfPid;
    
    uint256 public allQuantity;
    
    uint256 public allCurrentQuantity;

    constructor(
        IPdx _pdx,
        IFactory _factory,
        IOracle _oracle,
        address _router,
        address _targetToken,
        uint256 _startBlock
    ) public {
        pdx = _pdx;
        factory = _factory;
        oracle = _oracle;
        router = _router;
        targetToken = _targetToken;
        startBlock = _startBlock;
    }

    struct UserInfo {
        uint256 quantity;       // How many LP tokens the user has provided
        uint256 blockNumber;    // Last transaction block
    }

    struct PoolInfo {
        address pair;           // Trading pairs that can be mined
        uint256 quantity;       // Current amount of LPs
        uint256 totalQuantity;  // All quantity
    }

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;


    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }


    function addPair(uint256 _allocPoint, address _pair) public onlyOwner {
        require(_pair != address(0), "_pair is the zero address");
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            pair : _pair,
            quantity : 0,
            totalQuantity : 0
        }));
        pairOfPid[_pair] = poolLength() - 1;
    }

    // Only tokens in the whitelist can be mined PDX
    function addWhitelist(address _addToken) public onlyOwner returns (bool) {
        require(_addToken != address(0), "SwapMining: token is the zero address");
        return EnumerableSet.add(_whitelist, _addToken);
    }

    function delWhitelist(address _delToken) public onlyOwner returns (bool) {
        require(_delToken != address(0), "SwapMining: token is the zero address");
        return EnumerableSet.remove(_whitelist, _delToken);
    }

    function getWhitelistLength() public view returns (uint256) {
        return EnumerableSet.length(_whitelist);
    }

    function isWhitelist(address _token) public view returns (bool) {
        return EnumerableSet.contains(_whitelist, _token);
    }

    function getWhitelist(uint256 _index) public view returns (address){
        require(_index <= getWhitelistLength() - 1, "SwapMining: index out of bounds");
        return EnumerableSet.at(_whitelist, _index);
    }

    function setRouter(address newRouter) public onlyOwner {
        require(newRouter != address(0), "SwapMining: new router is the zero address");
        router = newRouter;
    }

    function setOracle(IOracle _oracle) public onlyOwner {
        require(address(_oracle) != address(0), "SwapMining: new oracle is the zero address");
        oracle = _oracle;
    }

    // swapMining only router
    function swap(address account, address input, address output, uint256 amount) public onlyRouter returns (bool) {
        require(account != address(0), "SwapMining: taker swap account is the zero address");
        require(input != address(0), "SwapMining: taker swap input is the zero address");
        require(output != address(0), "SwapMining: taker swap output is the zero address");

        if (poolLength() <= 0) {
            return false;
        }

        if (!isWhitelist(input) || !isWhitelist(output)) {
            return false;
        } 

        address pair = IFactory(factory).pairFor(input, output);

        PoolInfo storage pool = poolInfo[pairOfPid[pair]];
        // If it does not exist or the allocPoint is 0 then return
        if (pool.pair != pair) {
            return false;
        }

        uint256 quantity = getQuantity(output, amount, targetToken);
        if (quantity <= 0) {
            return false;
        }

        pool.quantity = pool.quantity.add(quantity);
        pool.totalQuantity = pool.totalQuantity.add(quantity);
        UserInfo storage user = userInfo[pairOfPid[pair]][account];
        user.quantity = user.quantity.add(quantity);
        user.blockNumber = block.number;
        return true; 
    }

    // The user withdraws all the transaction rewards of the pool
    function takerWithdraw() public {
        uint256 userSub;
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            UserInfo storage user = userInfo[pid][msg.sender];
            if (user.quantity > 0) {
                pool.quantity = pool.quantity.sub(user.quantity);
                userSub = getPdxRewards(user.quantity);
                user.quantity = 0;
                user.blockNumber = block.number;
            }
        }
        if (userSub <= 0) {
            return;
        }
        pdx.mint(msg.sender, userSub);
    }
    
    function getPdxPrice(uint256 _quantity) public view returns (uint256){
        address _pair = IFactory(factory).pairFor(address(pdx), targetToken);
        IPair _pdxTargetPair = IPair(_pair);
        uint256 _amount = _pdxTargetPair.price(targetToken,_quantity);
        return _amount;
    }
    
    function getPdxRewards(uint256 _quantity) private view returns (uint256){
        uint256 _pdx = getPdxPrice(_quantity);
        return _pdx.mul(18).div(9970);
    }

    // Get rewards from users in the current pool
    function getUserReward(uint256 _pid) public view returns (uint256, uint256){
        require(_pid <= poolInfo.length - 1, "SwapMining: Not find this pool");
        uint256 userSub;
        UserInfo memory user = userInfo[_pid][msg.sender];
        if (user.quantity > 0) {
            userSub = getPdxRewards(user.quantity);
        }
        //pdx available to users, User transaction amount
        return (userSub, user.quantity);
    }

    // Get details of the pool
    function getPoolInfo(uint256 _pid) public view returns (address, address, uint256, uint256, uint256 ,uint256){
        require(_pid <= poolInfo.length - 1, "SwapMining: Not find this pool");
        PoolInfo memory pool = poolInfo[_pid];
        address token0 = IPair(pool.pair).token0();
        address token1 = IPair(pool.pair).token1();
        uint256 pdxAmount = getPdxPrice(pool.quantity);
        uint256 currentPdx = getPdxRewards(pool.quantity);
        return (token0, token1, pdxAmount, pool.totalQuantity, pool.quantity,currentPdx);
    }

    modifier onlyRouter() {
        require(msg.sender == router, "SwapMining: caller is not the router");
        _;
    }

    function getQuantity(address outputToken, uint256 outputAmount, address anchorToken) public view returns (uint256) {
        uint256 quantity = 0;
        if (outputToken == anchorToken) {
            quantity = outputAmount;
        } else if (IFactory(factory).getPair(outputToken, anchorToken) != address(0)) {
            quantity = IOracle(oracle).consult(outputToken, outputAmount, anchorToken);
        } else {
            uint256 length = getWhitelistLength();
            for (uint256 index = 0; index < length; index++) {
                address intermediate = getWhitelist(index);
                if (IFactory(factory).getPair(outputToken, intermediate) != address(0) && IFactory(factory).getPair(intermediate, anchorToken) != address(0)) {
                    uint256 interQuantity = IOracle(oracle).consult(outputToken, outputAmount, intermediate);
                    quantity = IOracle(oracle).consult(intermediate, interQuantity, anchorToken);
                    break;
                }
            }
        }
        return quantity;
    }

}