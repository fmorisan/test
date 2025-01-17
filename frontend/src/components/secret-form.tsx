import { useState } from "react"
import { bytesToHex, encodePacked, hexToBigInt, keccak256, parseAbi, stringToBytes } from "viem"
import { useChainId, useSignTypedData, useWriteContract } from "wagmi"
import { Form, FormControl, FormField, FormItem, FormLabel } from "./ui/form"
import { zodResolver } from '@hookform/resolvers/zod'

import { z } from 'zod'
import { useForm } from "react-hook-form"
import { Input } from "./ui/input"
import { Button } from "./ui/button"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "./ui/dialog"
import { CONTRACT_ABI, SIGN_TYPES, VERIFYING_CONTRACTS } from "@/config/contracts"

const formSchema = z.object({
    message: z.string(),
})

interface SignatureFormProps {
    message?: string,
    salt?: BigInt,
    otherSignature?: `0x${string}`
}

export default function SecretForm(props: SignatureFormProps) {
    const form = useForm<z.infer<typeof formSchema>>({
        resolver: zodResolver(formSchema),
        defaultValues: {
            message: props.message || ''
        }
    })
    const { writeContract } = useWriteContract()
    const { signTypedData } = useSignTypedData()
    const chainid = useChainId()
    const [salt, setSalt] = useState<BigInt>(
        props.salt
        || hexToBigInt(
            keccak256(encodePacked(['string'], ["TODO: make this actually random"]))
        )
    )
    const [dialogOpen, setDialogOpen] = useState<boolean>(false)
    const [dataFragment, setDataFragment] = useState<string>('')

    function onFormSubmitted(values: z.infer<typeof formSchema>) {
        console.log(values)
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
                hash: keccak256(encodePacked(['bytes', 'uint256'], [bytesToHex(stringToBytes(values.message)), salt.valueOf()])),
                salt: salt.valueOf()
            },
        }, {
            onSuccess: (sig: `0x${string}`) => {
                const hash = keccak256(encodePacked(['bytes', 'uint256'], [bytesToHex(stringToBytes(values.message)), salt.valueOf()]))
                if (!props.otherSignature) {
                    // NOTE: Send URL to other party in order to get them to sign it and send it
                    const send = {
                        sig: sig, message: values.message, hash, salt: salt.toString()
                    }

                    let dataFragment = Buffer.from(
                            JSON.stringify(send)
                    ).toString('base64')

                    setDataFragment(dataFragment)
                    setDialogOpen(true)

                    console.log(
                        send
                    )
                } else {
                    // NOTE: we have both signatures now.
                        writeContract({
                            address: VERIFYING_CONTRACTS[chainid],
                            abi: parseAbi(CONTRACT_ABI),
                            functionName: 'commitSecret',
                            args: [hash, salt.valueOf(), [sig, props.otherSignature]]
                        })
                }
                //location.hash = dataFragment
                //location.reload()
            }
        })

    }

    return <Form {...form}>
        <form onSubmit={form.handleSubmit(onFormSubmitted)} className="space-y-8 space-x-8">
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
