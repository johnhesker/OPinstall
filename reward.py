from web3 import Web3, Account
import sys

# Connect to Oasis
rpc = 'https://sapphire.oasis.io'
web3 = Web3(Web3.HTTPProvider(rpc))

if not web3.is_connected():
    print("Failed to connect to the Oasis network.")
    sys.exit()


def read_file() -> list[str]:
    """
    Читает приватные ключи из файла wallets.txt.

    Returns:
        list[str]: Список приватных ключей из файла.
    """
    with open('wallets.txt', 'r') as file:
        return [line.strip().split()[0] for line in file if line.strip()]


def check_balances() -> None:
    """
    Проверяет и выводит баланс каждого кошелька, записанного в wallets.txt.
    Также выводит общую сумму средств на всех кошельках.
    """
    private_keys = read_file()
    total_balance = 0
    for pk in private_keys:
        account = web3.eth.account.from_key(pk)
        from_address = account.address
        balance = web3.eth.get_balance(from_address)

        if balance == 0:
            print(f"Адрес {from_address} имеет нулевой баланс. Пропускаем.")
        else:
            print(f"Баланс адреса {from_address}: {web3.from_wei(balance, 'ether')} ROSE")
            total_balance += balance

    print(f"Общая сумма на всех кошельках: {web3.from_wei(total_balance, 'ether')} ROSE")


def transfer_funds() -> None:
    """
    Переводит все доступные средства с каждого кошелька из wallets.txt
    на указанный адрес, после вычета комиссии за транзакцию.

    Запрашивает адрес назначения у пользователя и проверяет его на корректность.
    """
    private_keys = read_file()
    destination_address = input("Введите адрес кошелька для получения средств: ")

    if not web3.is_address(destination_address):
        print("Введен неверный адрес.")
        return

    for pk in private_keys:
        account = web3.eth.account.from_key(pk)
        from_address = account.address
        balance = web3.eth.get_balance(from_address)

        if balance == 0:
            print(f"Адрес {from_address} имеет нулевой баланс. Пропускаем.")
            continue

        gas_price = web3.eth.gas_price

        # Формируем временную транзакцию для оценки газа
        temp_tx = {
            'from': from_address,
            'to': destination_address,
            'value': balance,
        }

        try:
            # Оценка газ-лимита для транзакции
            gas_limit = web3.eth.estimate_gas(temp_tx)
        except Exception as e:
            print(f"Не удалось оценить газ для {from_address}: {e}")
            continue

        gas_cost = gas_price * gas_limit

        if balance <= gas_cost:
            print(f"Недостаточно средств на {from_address} для покрытия комиссии. Пропускаем.")
            continue

        value_to_send = balance - gas_cost
        tx = {
            'from': from_address,
            'to': destination_address,
            'value': value_to_send,
            'gas': gas_limit,
            'gasPrice': gas_price,
            'nonce': web3.eth.get_transaction_count(from_address, 'pending'),
        }

        signed_tx = web3.eth.account.sign_transaction(tx, private_key=pk)
        tx_hash = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
        print(f"Транзакция отправлена с {from_address}. Хэш транзакции: {web3.to_hex(tx_hash)}")

    print("Все транзакции обработаны.")


def menu() -> None:
    """
    Меню выбора действий. Позволяет пользователю выбирать между проверкой балансов,
    переводом средств и генерацией новых кошельков.
    """
    while True:
        print("\nВыберите действие:")
        print("1. Проверить баланс кошельков")
        print("2. Перевести средства на указанный адрес")
        print("0. Выход")

        choice = input("Ваш выбор: ")
        if choice == '1':
            check_balances()
        elif choice == '2':
            transfer_funds()
        elif choice == '0':
            print("Выход из программы.")
            break
        else:
            print("Неверный выбор. Попробуйте снова.")


if __name__ == "__main__":
    menu()