import { useState } from "react"
import { bytesToHex, encodePacked, hashTypedData, hexToBigInt, keccak256, parseAbi, stringToBytes } from "viem"
import { useAccount, useChainId, useReadContract, useSignTypedData, useWriteContract } from "wagmi"
import { Form, FormControl, FormField, FormItem, FormLabel } from "./ui/form"
import { zodResolver } from '@hookform/resolvers/zod'

import { string, z } from 'zod'
import { useForm } from "react-hook-form"
import { Input } from "./ui/input"
import { Button } from "./ui/button"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "./ui/dialog"
import { Alert, AlertDescription } from "./ui/alert"
import { CONTRACT_ABI, SIGN_TYPES, VERIFYING_CONTRACTS } from "@/config/contracts"

const formSchema = z.object({
    message: z.string(),
})

interface SignatureFormProps {
    secretId: bigint,
}

export default function RevealForm(props: SignatureFormProps) {
    const chainid = useChainId()
    const { address } = useAccount()
    const { signTypedData } = useSignTypedData()
    const { data } = useReadContract({
        address: VERIFYING_CONTRACTS[chainid],
        abi: parseAbi(CONTRACT_ABI),
        functionName: 'secrets',
        args: [props.secretId]
    })
    const form = useForm<z.infer<typeof formSchema>>({
        resolver: zodResolver(formSchema),
        defaultValues: {
            message: ''
        }
    })
    const { writeContract } = useWriteContract()

    let {message: inputMessage} = form.watch()

    let [commitment, partyA, partyB, salt] = data || []
    let calculatedCommitmentHash = keccak256(encodePacked(['bytes', 'uint256'], [bytesToHex(stringToBytes(inputMessage)), salt || 0n]))

    const {data: myNonce} = useReadContract({
        address: VERIFYING_CONTRACTS[chainid],
        abi: parseAbi(CONTRACT_ABI),
        functionName: 'nonces',
        args: [address!]
    })

    if (!data) { return <>Loading secret {props.secretId}...</> }

    function onFormSubmitted(values: z.infer<typeof formSchema>) {
        signTypedData({
            types: SIGN_TYPES,
            domain: {
                version: "0.1",
                name: "SecretHolder",
                verifyingContract: VERIFYING_CONTRACTS[chainid],
                chainId: BigInt(chainid).valueOf()
            },
            primaryType: 'Reveal',
            message: {
                id: props.secretId,
                message: bytesToHex(stringToBytes(values.message)),
                nonce: myNonce!
            }
        }, {
            onSuccess: (signature) => {
                writeContract({
                    address: VERIFYING_CONTRACTS[chainid],
                    abi: parseAbi(CONTRACT_ABI),
                    functionName: 'revealSecretSigned',
                    args: [props.secretId, values.message, myNonce!, signature]
                })
            }
        })
    }

    return <Form {...form}>
        <form onSubmit={form.handleSubmit(onFormSubmitted)} className="space-y-8 space-x-8">
            <FormField control={form.control} name="message" render={({field}: {field: any}) =>
                <FormItem>
                <FormLabel>Message to reveal</FormLabel>
                <FormControl>
                    <Input placeholder="hello!" {...field} />
                </FormControl>
                </FormItem>
            }/>
            <Button type="submit">Reveal Message</Button>
        </form>
        <Alert variant={calculatedCommitmentHash != commitment ? 'destructive' : undefined}>
            <AlertDescription>{calculatedCommitmentHash == commitment? 'Hashes match. Ready to reveal.' : 'Hashes do not match!'} </AlertDescription>
        </Alert>
    </Form>

        /*<form onSubmit={onFormSubmitted}>
        <label>Message to sign:</label>
        <input type="text" value={message} onChange={(e) => setMessage(e.target.value)}></input>
        <button type="submit">Sign</button>
        {dataFragment && <p>Give your counterpart this link: <b>http://localhost:3000/#{dataFragment}</b></p>}
    </form>*/
}
