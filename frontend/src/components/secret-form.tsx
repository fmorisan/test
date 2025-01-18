import { useEffect, useState } from "react"
import { bytesToHex, encodePacked, hexToBigInt, keccak256, parseAbi, parseTransaction, stringToBytes, verifyTypedData, zeroAddress } from "viem"
import { useAccount, useChainId, useClient, useReadContract, useSignTypedData, useWriteContract } from "wagmi"
import { Form, FormControl, FormField, FormItem, FormLabel } from "./ui/form"
import { zodResolver } from '@hookform/resolvers/zod'

import { z } from 'zod'
import { useForm } from "react-hook-form"
import { Input } from "./ui/input"
import { Button } from "./ui/button"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "./ui/dialog"
import { CONTRACT_ABI, SIGN_TYPES, VERIFYING_CONTRACTS } from "@/config/contracts"
import { readContract } from "viem/actions"

const formSchema = z.object({
    message: z.string(),
    partyA: z.string(),
    partyB: z.string()
}).refine((obj: any) => obj.partyA !== obj.partyB)

export interface PrefilledMessageParams {
    partyA: `0x${string}`
    partyB: `0x${string}`
}

export interface FragmentData {
    sig: `0x${string}`
    message: string
    salt: `0x${string}`
    prefilled: PrefilledMessageParams,
}

interface SignatureFormProps {
    otherSignature?: `0x${string}`,
    data: FragmentData | null
}

export default function SecretForm(props: SignatureFormProps) {
    const client = useClient()
    const { address } = useAccount()
    const form = useForm<z.infer<typeof formSchema>>({
        resolver: zodResolver(formSchema),
        defaultValues: {
            message: props.data?.message || '',
            partyA: props.data?.prefilled.partyA || address!,
            partyB: props.data?.prefilled.partyB || zeroAddress
        }
    })
    const { writeContract } = useWriteContract()
    const { signTypedData } = useSignTypedData()
    const chainid = useChainId()
    const [salt, setSalt] = useState<`0x${string}`>(
        props.data?.salt || keccak256(encodePacked(['string'], ["TODO: make this actually random"]))
    )
    const [dialogOpen, setDialogOpen] = useState<boolean>(false)
    const [dataFragment, setDataFragment] = useState<string>('')

    useEffect(() => {
        if (props.data && props.data.prefilled.partyB != address) {
            console.error("you're not meant to sign this")
        }
    }, [props.data])

    async function onFormSubmitted(values: z.infer<typeof formSchema>) {

        const nonceA = await readContract(client!, {
            address: VERIFYING_CONTRACTS[chainid],
            abi: parseAbi(CONTRACT_ABI),
            functionName: 'nonces',
            args: [values.partyA as `0x${string}`]
        })

        const nonceB = await readContract(client!, {
            address: VERIFYING_CONTRACTS[chainid],
            abi: parseAbi(CONTRACT_ABI),
            functionName: 'nonces',
            args: [values.partyB as `0x${string}`]
        })



        signTypedData({
            domain: {
                version: "0.1",
                name: "SecretHolder",
                verifyingContract: VERIFYING_CONTRACTS[chainid],
                chainId: BigInt(chainid).valueOf()
            },
            types: SIGN_TYPES,
            primaryType: "Secret",
            message: {
                hash: keccak256(encodePacked(['bytes', 'uint256'], [bytesToHex(stringToBytes(values.message)), BigInt(salt).valueOf()])),
                salt: BigInt(salt).valueOf(),
                partyA: values.partyA as `0x${string}`,
                partyB: values.partyB as `0x${string}`,
                nonceA: nonceA,
                nonceB: nonceB
            },
        }, {
            onSuccess: (sig: `0x${string}`, args) => {
                const hash = keccak256(encodePacked(['bytes', 'uint256'], [bytesToHex(stringToBytes(values.message)), BigInt(salt).valueOf()]))
                if (!props.data?.sig) {

                    const fragmentBuild: FragmentData = {
                        sig,
                        message: values.message,
                        salt: salt,
                        prefilled: {
                            partyA: values.partyA as `0x${string}`,
                            partyB: values.partyB as `0x${string}`
                        }
                    }


                    // NOTE: Send URL to other party in order to get them to sign it and send it
                    let dataFragment = Buffer.from(
                            JSON.stringify({sig, message: values.message, prefilled: {hash: hash, salt: salt.toString(), partyA: values.partyA, partyB: values.partyB}})
                    ).toString('base64')

                    setDataFragment(dataFragment)
                    setDialogOpen(true)
                } else {
                    // NOTE: we have both signatures now.
                        writeContract({
                            address: VERIFYING_CONTRACTS[chainid],
                            abi: parseAbi(CONTRACT_ABI),
                            functionName: 'commitSecret',
                            args: [hash, BigInt(salt).valueOf(), props.data.prefilled.partyA, props.data.prefilled.partyB, [props.data.sig, sig]]
                        })
                }
            }
        })

    }

    return <Form {...form}>
        <form onSubmit={form.handleSubmit(onFormSubmitted)} className="space-y-8 space-x-8">
            <FormField control={form.control} name="partyA" render={({field}: {field: any}) =>
                <FormItem>
                <FormLabel>Signer 1</FormLabel>
                <FormControl>
                    <Input placeholder="hello!" {...field} />
                </FormControl>
                </FormItem>
            }/>
            <FormField control={form.control} name="partyB" render={({field}: {field: any}) =>
                <FormItem>
                <FormLabel>Signer 2</FormLabel>
                <FormControl>
                    <Input placeholder="hello!" {...field} />
                </FormControl>
                </FormItem>
            }/>
            <FormField control={form.control} name="message" render={({field}: {field: any}) =>
                <FormItem>
                <FormLabel>Message to sign</FormLabel>
                <FormControl>
                    <Input placeholder="hello!" {...field} />
                </FormControl>
                </FormItem>
            }/>
            <Button type="submit">Sign message</Button>
        </form>
        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
            <DialogContent>
                <DialogHeader>
                    <DialogTitle>Signed successfully</DialogTitle>
                </DialogHeader>
                <DialogDescription>
                <p>You can now send the following link to your counterpart so that they can sign this message as well:</p>
                <a href={`${location.host}${location.pathname}/#${dataFragment}`}>Link</a>
                </DialogDescription>
            </DialogContent>
            </Dialog>
    </Form>

        /*<form onSubmit={onFormSubmitted}>
        <label>Message to sign:</label>
        <input type="text" value={message} onChange={(e) => setMessage(e.target.value)}></input>
        <button type="submit">Sign</button>
        {dataFragment && <p>Give your counterpart this link: <b>http://localhost:3000/#{dataFragment}</b></p>}
    </form>*/
}
