"use client";

import Link from "next/link";
import { useEffect, useState, useRef } from 'react';
import type { NextPage } from "next";
import { useAccount, useContractRead } from "wagmi";
import { BugAntIcon, MagnifyingGlassIcon } from "@heroicons/react/24/outline";
import { Address, EtherInput, InputBase } from "~~/components/scaffold-eth";
import { readContract } from "viem/_types/actions/public/readContract";
import { useScaffoldContract, useScaffoldContractRead, useScaffoldContractWrite } from "~~/hooks/scaffold-eth";
import SetBillboard from '../components/SetBillboard';
import MintNFT from '../components/MintNFT';
import WithdrawShare from '../components/WithdrawShare';

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const { data: billboardMessage } = useScaffoldContractRead({
      contractName: "YourContract",
      functionName: "billboard",
  })

  const { data: getAdjustedPrice } = useScaffoldContractRead({
    contractName: "YourContract",
    functionName: "getAdjustedPrice",
})

// get price + let user set their own
const [ethAmount, setEthAmount] = useState('');
const initialLoadDone = useRef(false);

useEffect(() => {
  if (getAdjustedPrice && !initialLoadDone.current) {
    setEthAmount(getAdjustedPrice.toString());
    initialLoadDone.current = true;
  }
}, [getAdjustedPrice]);

console.log(ethAmount, typeof(ethAmount));

const [bString, setbString] = useState<string>();

  // const { writeAsync, isLoading, isMining } = useScaffoldContractWrite ({
  //   contractName: "YourContract",
  //   functionName: "setBillboard",
  //   args: [bString],
  //   value: ethAmount,
  // })

  // const { writeAsync, isLoading, isMining } = useScaffoldContractWrite ({
  //   contractName: "YourContract",
  //   functionName: "mintNFT",
  // })

  // const { writeAsync, isLoading, isMining } = useScaffoldContractWrite ({
  //   contractName: "YourContract",
  //   functionName: "shareWithdraw",
  //   args: []
  // })
  return (
    <>
      <div className="flex items-center flex-col flex-grow pt-10">
        <div className="px-5">
          <div className="text-center">
            Billboard Message: {billboardMessage} <br />
            AdjustedPrice: {getAdjustedPrice?.toString()} <br />
            EthAmount: {ethAmount}

            <SetBillboard
              ethAmount={ethAmount}
            />
 
          <MintNFT />
          <WithdrawShare />


          {/* TODOS
            - Change Message
              - Add URL string (?)  --- SC
              - Add string limits on both --- SC
            - Mint NFT --- FE
            - Withdraw Amount --- FE
              - STRETCH/OPTIONAL: Show all available epochs to withdraw --- FE
                - Add message and url to epoch (?) -- SC
            - 
            */}
          </div>
          <div className="flex justify-center items-center space-x-2">
            <p className="my-2 font-medium">Connected Address:</p>
            <Address address={connectedAddress} />
          </div>
          <p className="text-center text-lg">
            Get started by editing{" "}
            <code className="italic bg-base-300 text-base font-bold max-w-full break-words break-all inline-block">
              packages/nextjs/app/page.tsx
            </code>
          </p>
          <p className="text-center text-lg">
            Edit your smart contract{" "}
            <code className="italic bg-base-300 text-base font-bold max-w-full break-words break-all inline-block">
              YourContract.sol
            </code>{" "}
            in{" "}
            <code className="italic bg-base-300 text-base font-bold max-w-full break-words break-all inline-block">
              packages/hardhat/contracts
            </code>
          </p>
        </div>

        <div className="flex-grow bg-base-300 w-full mt-16 px-8 py-12">
          <div className="flex justify-center items-center gap-12 flex-col sm:flex-row">
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <BugAntIcon className="h-8 w-8 fill-secondary" />
              <p>
                Tinker with your smart contract using the{" "}
                <Link href="/debug" passHref className="link">
                  Debug Contracts
                </Link>{" "}
                tab.
              </p>
            </div>
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <MagnifyingGlassIcon className="h-8 w-8 fill-secondary" />
              <p>
                Explore your local transactions with the{" "}
                <Link href="/blockexplorer" passHref className="link">
                  Block Explorer
                </Link>{" "}
                tab.
              </p>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default Home;
