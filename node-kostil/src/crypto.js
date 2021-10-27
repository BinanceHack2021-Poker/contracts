import HDWalletProvider from "@truffle/hdwallet-provider"
import Web3 from "web3"
import axios from "axios"

import ethJSUtil from 'ethereumjs-util'
//import call from "remix"
//import { erc721Abi } from "./contracts/raribleTransferContractAbi.js"

import { createRaribleSdk } from "@rarible/protocol-ethereum-sdk"

import { toAddress } from "@rarible/types"
import { toBigNumber } from "@rarible/types"
import { Web3Ethereum } from "@rarible/web3-ethereum"

import keccak256 from "keccak256"

import FormData from "form-data"; // a nodejs module.
global.FormData = FormData; // hack for nodejs;

import fetchApi from "node-fetch"; // a nodejs module.
global.window = {
    fetch: fetchApi,
}
//global.window = {fetch: {bind: }}

// DO NOT PUSH PRIVATE KEYS IN PUBLIC REPO!
const config = {
	mainnetRpc: "https://mainnet.infura.io/v3/84653a332a3f4e70b1a46aaea97f0435",
 	rinkebyRpc: "https://rinkeby.infura.io/v3/84653a332a3f4e70b1a46aaea97f0435",
 	rinkeby: "rinkeby"
}


export async function SignMessage(body) {
    const maker = new HDWalletProvider(body.private_ext, config.rinkebyRpc)
    const web3 = new Web3(maker)
    signMessageImpl(web3, body.msg, body.private_ext)
}

export async function signMessageImpl(web3, msg, privateKey) {
    try {
        const personalMsg = ethJSUtil.hashPersonalMessage(Buffer.from(msg))
        var rsv = ethJSUtil.ecsign(personalMsg, privateKey)
        var signedData = ethJSUtil.toRpcSig(rsv.v, rsv.r, rsv.s)
        console.log('0x' + personalMsg.toString('hex'), signedData)
        return {"hash": '0x' + personalMsg.toString('hex'), "signature": signedData}
    } catch (e) {
        console.log(e.message)
    }
}

export async function Deploy(body) {
    const maker = new HDWalletProvider(body.private_ext, config.rinkebyRpc)
    const web3 = new Web3(maker)
    return deployImpl(web3)
}

import fs from "fs"

export async function deployImpl(web3) {
    try {
        console.log('Running deployWithWeb3 script...')

        const contractName = 'ChainHoldem' // Change this for other contract
        const constructorArgs = ['10000000000000000']    // Put constructor args (if any) here for your contract - comission - 0.01 eth

        // Note that the script needs the ABI which is generated from the compilation artifact.
        // Make sure contract is compiled and artifacts are generated

        const artifactsPath = `/usr/src/app/src/contracts/artifacts/${contractName}.json` // Change this for different path

        const content = await fs.readFileSync(artifactsPath, 'utf8');


        const metadata = await JSON.parse(content)
        const accounts = await web3.eth.getAccounts()

        let contract = new web3.eth.Contract(metadata.abi)

        contract = contract.deploy({
            data: metadata.data.bytecode.object,
            arguments: constructorArgs
        })

        const newContractInstance = await contract.send({
            from: accounts[0],
            gas: 1500000,
            gasPrice: '30000000000'
        })
        console.log('Contract deployed at address: ', newContractInstance.options.address)
        return newContractInstance.options.address
    } catch (e) {
        console.log(e.message)
    }
}


export async function CallMethod(body) {
    const maker = new HDWalletProvider(body.private_ext, config.rinkebyRpc)
    const web3 = new Web3(maker)
    callMethodImpl(web3, body)
}

export async function callMethodImpl(web3, body) {
//    try {
        const contractName = 'ChainHoldem' // Change this for other contract
        const constructorArgs = []    // Put constructor args (if any) here for your contract

        // Note that the script needs the ABI which is generated from the compilation artifact.
        // Make sure contract is compiled and artifacts are generated

        const artifactsPath = `/usr/src/app/src/contracts/artifacts/${contractName}.json` // Change this for different path

        const content = fs.readFileSync(artifactsPath, 'utf8');

        const metadata = JSON.parse(content)
        const accounts = await web3.eth.getAccounts()

        let contract = new web3.eth.Contract(metadata.abi, body.contract_address)

        console.log(body.args_json)
        let method = await buildMethod(contract, body.method, body.args_json)
//        console.log(method)
        const tx = await method.send({
            from: accounts[0],
            gas: 1500000,
            gasPrice: '30000000000'
        }).then((result) => {
            }, (error) => {
        console.log(error);
        });
        console.log("tx: ", tx)
//    } catch (e) {
//        console.log(e.message)
//    }
}

export async function buildMethod(contract, method, args) {
    if (method == "revealCards") {
        return contract.methods[method](args.game_id, args.card_hash, args.hash)
    }
    assert(false);
}