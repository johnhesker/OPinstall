import os
from eth_account import Account
from eth_utils import to_hex

# Generate wallets
def generate_wallets(count):
    wallets = []
    for _ in range(count):
        acct = Account.create()
        wallets.append(f"{to_hex(acct.key)} {acct.address}")
    return wallets

# Save generated wallets to file wallets.txt
def save_wallets(wallets):
    with open('wallets.txt', 'w') as f:
        for wallet in wallets:
            f.write(f"{wallet}\n")
    print("Generated wallets stored in wallets.txt file")

if __name__ == "__main__":
    # Node count
    node_count = int(input("Enter the number of wallets to generate: "))
    wallets = generate_wallets(node_count)
    save_wallets(wallets)
