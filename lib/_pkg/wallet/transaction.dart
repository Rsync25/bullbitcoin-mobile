import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletTx {
  Future<(Wallet?, Err?)> getTransactions({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final storedTxs = wallet.transactions ?? [];
      final txs = await bdkWallet.listTransactions(true);
      // final x = bdk.TxBuilderResult();

      if (txs.isEmpty) throw 'No bdk transactions found';

      final List<Transaction> transactions = [];
      for (final tx in txs) {
        final idx = storedTxs.indexWhere((t) => t.txid == tx.txid);

        Transaction? storedTx;
        if (idx != -1) storedTx = storedTxs.elementAtOrNull(idx);

        var txObj = Transaction(
          txid: tx.txid,
          received: tx.received,
          sent: tx.sent,
          fee: tx.fee ?? 0,
          height: tx.confirmationTime?.height ?? 0,
          timestamp: tx.confirmationTime?.timestamp ?? 0,
          bdkTx: tx,
          rbfEnabled: storedTx?.rbfEnabled ?? false,
          // label: label,
        );

        var label = '';

        final address = wallet.getAddressFromAddresses(
          txObj.txid,
          isSend: !txObj.isReceived(),
        );

        if (idx != -1 && storedTxs[idx].label != null && storedTxs[idx].label!.isNotEmpty)
          label = storedTxs[idx].label!;
        else if (address != null && address.label != null && address.label!.isNotEmpty)
          label = address.label!;

        if (txObj.isReceived()) {
          // final fromAddress = state.wallet!.getAddressFromTxid(txObj.txid);

          txObj = txObj.copyWith(
            toAddress: address?.address ?? '',
            fromAddress: '',
          );
        } else {
          final fromAddress = wallet.getAddressFromTxid(txObj.txid);
          if (idx != -1) {
            final broadcastTime = storedTxs[idx].broadcastTime;
            txObj = txObj.copyWith(broadcastTime: broadcastTime);
          }
          txObj = txObj.copyWith(
            toAddress: address?.address ?? '',
            fromAddress: fromAddress,
          );
        }

        transactions.add(txObj.copyWith(label: label));
      }

      final w = wallet.copyWith(transactions: transactions);

      return (w, null);
    } catch (e) {
      return (null, Err(e.toString(), expected: e.toString() == 'No bdk transactions found'));
    }
  }

  Future<((Transaction?, int?, String)?, Err?)> buildTx({
    required Wallet wallet,
    required bdk.Wallet pubWallet,
    required bool isManualSend,
    required String address,
    required int? amount,
    required bool sendAllCoin,
    required double feeRate,
    required bool enableRbf,
    required List<Address> selectedAddresses,
    String? note,
  }) async {
    try {
      var txBuilder = bdk.TxBuilder();
      final bdkAddress = await bdk.Address.create(address: address);
      final script = await bdkAddress.scriptPubKey();

      if (sendAllCoin) {
        txBuilder = txBuilder.drainWallet().drainTo(script);
      } else {
        txBuilder = txBuilder.addRecipient(script, amount!);
      }

      for (final address in wallet.allFreezedAddresses())
        for (final unspendable in address.getUnspentUtxosOutpoints())
          txBuilder = txBuilder.addUnSpendable(unspendable);

      if (isManualSend) {
        txBuilder = txBuilder.manuallySelectedOnly();
        final utxos = <bdk.OutPoint>[];
        for (final address in selectedAddresses) utxos.addAll(address.getUnspentUtxosOutpoints());
        txBuilder = txBuilder.addUtxos(utxos);
      }

      txBuilder = txBuilder.feeRate(feeRate);

      if (enableRbf) txBuilder = txBuilder.enableRbf();

      final txResult = await txBuilder.finish(pubWallet);

      final txDetails = txResult.txDetails;

      final extractedTx = await txResult.psbt.extractTx();
      final outputs = await extractedTx.output();
      final outAddresses = await Future.wait(
        outputs.map((txOut) async {
          final address = await bdk.Address.fromScript(
            txOut.scriptPubkey,
            wallet.getBdkNetwork(),
          );
          return address.toString();
        }),
      );

      final tx = Transaction(
        txid: txDetails.txid,
        rbfEnabled: enableRbf,
        received: txDetails.received,
        sent: txDetails.sent,
        fee: txDetails.fee ?? 0,
        height: txDetails.confirmationTime?.height,
        timestamp: txDetails.confirmationTime?.timestamp,
        label: note,
        toAddress: address,
        outAddresses: outAddresses,
        psbt: txResult.psbt.psbtBase64,
      );
      final feeAmt = await txResult.psbt.feeAmount();
      return ((tx, feeAmt, txResult.psbt.psbtBase64), null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<((Wallet, String)?, Err?)> broadcastTxWithWallet({
    required String psbt,
    required bdk.Blockchain blockchain,
    required Wallet wallet,
    required String address,
    String? note,
  }) async {
    try {
      final psb = bdk.PartiallySignedTransaction(psbtBase64: psbt);
      final tx = await psb.extractTx();

      await blockchain.broadcast(tx);
      final txid = await psb.txId();
      final newTx = Transaction(
        txid: txid,
        label: note,
        toAddress: address,
        broadcastTime: DateTime.now().millisecondsSinceEpoch,
      );

      final txs = wallet.transactions?.toList() ?? [];
      txs.add(newTx);
      final w = wallet.copyWith(transactions: txs);

      return ((w, txid), null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<Err?> broadcastTx({
    required bdk.Transaction tx,
    required bdk.Blockchain blockchain,
  }) async {
    try {
      await blockchain.broadcast(tx);
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<(Wallet?, Err?)> updateRelatedTxLabels({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
    // ignore: type_annotate_public_apis
    required String label,
    required String address,
  }) async {
    try {
      return (wallet, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}