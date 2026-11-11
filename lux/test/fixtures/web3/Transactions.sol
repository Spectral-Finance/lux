// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Local integration fixtures, never deployed to a public chain by the tests.
contract CounterFixture {
    uint256 public count;

    function increment() external {
        count += 1;
    }

    function fail() external pure {
        revert("intentional test revert");
    }
}

contract AggregateFixture {
    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory results) {
        results = new Result[](calls.length);
        for (uint256 i; i < calls.length; ++i) {
            (bool success, bytes memory data) = calls[i].target.call(calls[i].callData);
            require(success || calls[i].allowFailure, "batch call failed");
            results[i] = Result(success, data);
        }
    }
}
