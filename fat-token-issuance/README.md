# Token issuance scripts

Note: These scripts are currently mostly for demo purposes, they require installation of some dependencies and are not production-ready.

To issue a token, the following actions need to be performed:
- Create an identity and register on blockchain (Identity Root Chain ID)
- Create a token chain
- Issue a total (maximum) amount of tokens

For this process, the following is needed as input:
- Entry credits address or Factoid address with which entry credits can be bought.
- The amount of tokens that need to be issued (maximum amount of tokens distributed)

## Dependencies
- Golang
  - https://tecadmin.net/install-go-on-ubuntu/
- `make`, `gcc`
  - `sudo apt install make gcc`
- factomd, factom-walletd, factom-cli
  - [Install Factom guide](https://github.com/FactomProject/FactomDocs/blob/master/installFromSourceDirections.md#install-factom)
- [serveridentity](https://github.com/FactomProject/serveridentity)
```
git clone git@github.com:FactomProject/serveridentity $GOPATH/src/github.com/FactomProject/serveridentity
glide install
go install
```


## Usage
As stated, the current scripts are for demo purposes. As such, there is a script that demonstrates all steps described above: `issue-tokens.sh`. It needs services that are started in `start-factomd-factomwallet-fatd.sh`.

The Factom configuration for the sanbox mode is stored in `~/.factom/m2/factomd.conf`:
```
[app]
DirectoryBlockInSeconds               = 30
Network                               = LOCAL
NodeMode                                = SERVER
```

Start needed services using `start-factomd-factomwallet-fatd.sh` as shown below:
```bash
$ ./start-factomd-factomwalletd-fatd.sh ../../fatd/
Starting factomd...
Starting factom-walletd...
Wait for Factom daemon API to be available...
Starting FATd...
```

Make sure that all services are running by checking the logs in `./logs`.

Then use the `issue-tokens.sh` script to take all the actions described above.
```
$ ./issue-tokens.sh ../../fatd/
------------------Entry credit addresses------------------
Newly created entry credit address: EC2P4JUGzfFDcB8taE7RCYnE4LA3bp8XvWrMmSWdYM5vwBagTc6v
Newly created entry credit address private key: Es48CeQPCFEUra15yJNUsJ8eEgD9GmDaFqXvNBxBKo9W1gjfsvy9
------------------Factoid addresses------------------
Newly created factoid address 1: FA2Z2mMa85avW2pREtHVpj7tSwa2rSj9L9oaPFVA5Y1gokFxWhCP
Newly created factoid address 2: FA2Hx2UGEUqUdZUPLqj4WmWz3nSjAXMeWCiezuv3W9HKqAx3XTJJ
....
------------------FAT0 token transaction------------------
Sleeping to finish transaction...
Balance on FA address 1: FA3doDoAjeASjtdxzP4RK3juD2FJzD3eecDB5TsR5T6Z1xQKP79a
15
Balance on FA address 2: FA3UYgMVoC6shdHEi1JikAPMnSHKAkwDveANAuDNtjoAFWHiXGLv
10
Transaction ID: 33bc6bf0434a67fdaf8bb2eaabb52199a02fc715c3a77ba205f41f2b87e5c31f
TxID: 33bc6bf0434a67fdaf8bb2eaabb52199a02fc715c3a77ba205f41f2b87e5c31f
Status: DBlockConfirmed
Date: 
```

## Troubleshooting
Should there be any errors or unexpected results, the first thing to check would be whether all services (Factom Daemon, Factom Wallet Daemon and FAT daemon) are running. Check the `./logs` folder to find issues with the services.
