import React, { useState, useEffect } from 'react';
import { Address, EtherInput, InputBase } from "~~/components/scaffold-eth";
import { useScaffoldContract, useScaffoldContractRead, useScaffoldContractWrite } from "~~/hooks/scaffold-eth";
import { useAccount } from 'wagmi';


interface WithdrawShareProps {

}

const WithdrawShare: React.FC<WithdrawShareProps> = ({  }) => {

  const [epoch, setEpoch] = useState<string>();
  const [bString, setbString] = useState<string>();

  const { address, isConnected } = useAccount();

  /// get the token id for user

  // const UserNFTInfo = ({ address : string }) => {
  //   const [userHasMinted, setUserHasMinted] = useState(false);
  //   const [tokenId, setTokenId] = useState(null);
  
    // Check if the user has minted a token
    // const { data: hasMinted } = useScaffoldContractRead({
    //   contractName: "YourContract",
    //   functionName: "userHasMinted",
    //   args: [address],
    // });
  
    // Retrieve the token ID if the user has minted a token
  //   useEffect(() => {
  //     if (hasMinted) {
  //       const fetchTokenId = async () => {
  //         const { data: id } = await useScaffoldContractRead({
  //           contractName: "YourNFTContract",
  //           functionName: "getTokenIdOfUser",
  //           args: [userAddress],
  //         });
  //         if (id) {
  //           setTokenId(id.toString());
  //           setUserHasMinted(true);
  //         }
  //       };
  
  //       fetchTokenId();
  //     }
  //   }, [hasMinted, userAddress]);

  const [tokenID, setTokenID] = useState<number | undefined>();
  const [epochID, setEpochID] = useState<number | undefined>(); 

  const { writeAsync, isLoading, isMining } = useScaffoldContractWrite ({
    contractName: "YourContract",
    functionName: "shareWithdraw",
    args: [tokenID, epochID],
  })

    return(
      <>
        <div>
          Withdraw Share for {address}
          <InputBase name="epoch ID" placeholder="What Epoch are you withdrawing from?" value={epochID} onChange={setEpochID}></InputBase>
          <InputBase name="token ID" placeholder="Your Token ID?" value={tokenID} onChange={setTokenID}></InputBase>
          <button className="btn btn-primary" onClick={() => writeAsync()} disabled={isLoading}>
            {isLoading ? <span className="loading loading-spinner loading-sm"></span> : <>Send</>}
          </button>
        </div>
      </>
    )
};

export default WithdrawShare;