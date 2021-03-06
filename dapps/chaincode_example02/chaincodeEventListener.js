/*
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const { FileSystemWallet, Gateway } = require('fabric-network');
const fs = require('fs');
const path = require('path');

const ccpPath = path.resolve(__dirname, 'connection.json');
const ccpJSON = fs.readFileSync(ccpPath, 'utf8');
const ccp = JSON.parse(ccpJSON);

async function main() {
    try {

        // Create a new file system based wallet for managing identities.
        const walletPath = path.join(process.cwd(), 'wallet');
        const wallet = new FileSystemWallet(walletPath);
        console.log(`Wallet path: ${walletPath}`);

        // Check to see if we've already enrolled the user.
        const userExists = await wallet.exists('user1');
        if (!userExists) {
            console.log('An identity for the user "user1" does not exist in the wallet');
            console.log('Run the registerUser.js application before retrying');
            return;
        }

        // Create a new gateway for connecting to our peer node.
        const gateway = new Gateway();
        await gateway.connect(ccp, { wallet, identity: 'user1', discovery: { enabled: false } });

        // Get the network (channel) our contract is deployed to.
        const network = await gateway.getNetwork('ch1');

        //------------------------------------------------------------------//
        // https://fabric-sdk-node.github.io/release-1.4/tutorial-channel-events.html
        const channel = network.getChannel();
        var promises = [];

        let event_hubs = channel.getChannelEventHubsForOrg();
        event_hubs.forEach((eh) => {

            let addChaincodeEventPromise = new Promise((reslove, reject) => {
                eh.registerChaincodeEvent('mycc', '[a-zA-Z0-9]+',
                    (event, block_num, txnid, status) => {
                        console.log(event);
                        console.log('Successfully got a chaincode event with block_num' + block_num + 'with transid:' + txnid + ' with status:' + status);
                    }, (err) => {
                        console.log(err);
                        reject(err);
                    }, {
                        // unregister will default to false
                        // disconnect will default to false
                        // as_array: true
                    }
                );
                eh.connect({full_block: true});
            });
            promises.push(addChaincodeEventPromise);
        });

        await Promise.all(promises);
        //------------------------------------------------------------------//

    } catch (error) {
        console.error(`Failed to evaluate transaction: ${error}`);
        process.exit(1);
    }
}

main();
