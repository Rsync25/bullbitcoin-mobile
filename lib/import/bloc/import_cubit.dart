import 'dart:convert';

import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/nfc.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImportWalletCubit extends Cubit<ImportState> {
  ImportWalletCubit({
    required this.barcode,
    required this.filePicker,
    required this.nfc,
    required this.settingsCubit,
    required this.walletCreate,
    required this.walletSensCreate,
    required this.hiveStorage,
    required this.secureStorage,
    required this.walletRepository,
    required this.walletSensRepository,
  }) : super(
          const ImportState(
              // words: [
              //   ...r2,
              // ],
              ),
        );

  final Barcode barcode;
  final FilePick filePicker;
  final NFCPicker nfc;

  final SettingsCubit settingsCubit;
  final WalletCreate walletCreate;
  final WalletSensitiveCreate walletSensCreate;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletRepository walletRepository;

  final WalletSensitiveRepository walletSensRepository;

  void backClicked() {
    switch (state.importStep) {
      case ImportSteps.importWords:
      case ImportSteps.selectImportType:
      case ImportSteps.importXpub:
        emit(
          state.copyWith(
            importStep: ImportSteps.selectCreateType,
            importType: ImportTypes.notSelected,
            // words: [for (int i = 0; i < 12; i++) ''],
          ),
        );

      case ImportSteps.scanningNFC:
      case ImportSteps.scanningWallets:
      case ImportSteps.selectWalletFormat:
        if (state.importType == ImportTypes.xpub)
          emit(
            state.copyWith(
              importStep: ImportSteps.importXpub,
              importType: state.importType,
            ),
          );
        else if (state.importType == ImportTypes.words)
          emit(
            state.copyWith(
              importStep: ImportSteps.importWords,
              importType: state.importType,
              words: [for (int i = 0; i < 12; i++) ''],
            ),
          );
        else if (state.importType == ImportTypes.coldcard)
          emit(
            state.copyWith(
              importStep: ImportSteps.importXpub,
              importType: state.importType,
            ),
          );
        emit(state.copyWith(errSavingWallet: ''));

        stopScanningNFC();

      default:
        break;
    }
  }

  void importClicked() {
    emit(
      state.copyWith(
        importStep: ImportSteps.importXpub,
        importType: ImportTypes.xpub,
      ),
    );
  }

  void recoverClicked() {
    emit(
      state.copyWith(
        importStep: ImportSteps.importWords,
        importType: ImportTypes.words,
      ),
    );
  }

  void scanQRClicked() async {
    emit(state.copyWith(loadingFile: true));
    final (res, err) = await barcode.scan();
    if (err != null) {
      emit(
        state.copyWith(
          errImporting: err.toString(),
          loadingFile: false,
        ),
      );
      return;
    }

    if (state.importStep == ImportSteps.importXpub) emit(state.copyWith(xpub: res!));

    emit(state.copyWith(loadingFile: false));
  }

  void wordChanged(int idx, String text) {
    final words = state.words.toList();
    words[idx] = text;
    emit(state.copyWith(words: words));
  }

  void passPhraseChanged(String text) {
    emit(state.copyWith(passPhrase: text));
  }

  void xpubChanged(String text) {
    emit(state.copyWith(xpub: text));
  }

  void descriptorChanged(String text) {
    emit(state.copyWith(manualPublicDescriptor: text));
  }

  void cDescriptorChanged(String text) {
    emit(state.copyWith(manualPublicChangeDescriptor: text));
  }

  void combinedDescriptorChanged(String text) {
    emit(
      state.copyWith(manualCombinedPublicDescriptor: text),
    );
    final desc = splitCombinedChanged(text, false);
    final cdesc = splitCombinedChanged(text, true);
    emit(
      state.copyWith(
        manualPublicDescriptor: desc,
        manualPublicChangeDescriptor: cdesc,
      ),
    );
  }

  void fingerprintChanged(String text) {
    emit(state.copyWith(fingerprint: text));
  }

  void customDerivationChanged(String text) {
    emit(state.copyWith(customDerivation: text));
  }

  void coldCardNFCClicked() async {
    emit(
      state.copyWith(
        importStep: ImportSteps.scanningNFC,
        loadingFile: true,
        errLoadingFile: '',
      ),
    );

    final err = await nfc.startSession(coldCardNFCReceived);
    if (err != null) {
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: err.toString(),
          loadingFile: false,
        ),
      );

      final errStopping = nfc.stopSession();
      if (errStopping != null)
        emit(
          state.copyWith(
            errLoadingFile: errStopping.toString(),
            loadingFile: false,
          ),
        );
    }
  }

  void stopScanningNFC() async {
    final err = nfc.stopSession();
    if (err != null) emit(state.copyWith(errLoadingFile: err.toString()));
    emit(state.copyWith(loadingFile: false));
  }

  void coldCardNFCReceived(String jsnStr) async {
    final ccObj = jsonDecode(jsnStr) as Map<String, dynamic>;
    final coldcard = ColdCard.fromJson(ccObj);

    emit(state.copyWith(coldCard: coldcard, importType: ImportTypes.coldcard));

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) {
      final errStoppping = nfc.stopSession();
      if (errStoppping != null)
        emit(
          state.copyWith(
            errLoadingFile: errStoppping.toString(),
            loadingFile: false,
          ),
        );
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: state.errImporting,
          loadingFile: false,
        ),
      );

      return;
    }

    emit(
      state.copyWith(
        importStep: ImportSteps.scanningWallets,
        loadingFile: false,
        importType: ImportTypes.coldcard,
      ),
    );
  }

  void coldCardFileClicked() async {
    emit(
      state.copyWith(
        loadingFile: true,
        errLoadingFile: '',
      ),
    );
    final (file, err) = await filePicker.pickFile();
    if (err != null) {
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: err.toString(),
          loadingFile: false,
        ),
      );
      return;
    }

    final ccObj = jsonDecode(file!) as Map<String, dynamic>;

    final coldcard = ColdCard.fromJson(ccObj);

    emit(state.copyWith(coldCard: coldcard, importType: ImportTypes.coldcard));

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) {
      emit(
        state.copyWith(
          importStep: ImportSteps.importXpub,
          errLoadingFile: state.errImporting,
          loadingFile: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        importStep: ImportSteps.scanningWallets,
        loadingFile: false,
        importType: ImportTypes.coldcard,
      ),
    );
  }

  void xpubSaveClicked() async {
    emit(state.copyWith(errImporting: ''));
    if (state.xpub.isEmpty) {
      emit(state.copyWith(errImporting: 'Please enter xpub'));
      return;
    }

    emit(
      state.copyWith(
        tempXpub: state.xpub,
        xpub: convertToXpubStr(state.xpub),
        importType: ImportTypes.xpub,
      ),
    );

    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) return;

    emit(state.copyWith(importStep: ImportSteps.scanningWallets));
  }

  void recoverWalletClicked() async {
    emit(state.copyWith(importType: ImportTypes.words, errImporting: ''));
    for (final word in state.words)
      if (word.isEmpty) {
        emit(state.copyWith(errImporting: 'Please fill all words'));
        return;
      }
    await _updateWalletDetailsForSelection();
    if (state.errImporting.isNotEmpty) return;

    emit(state.copyWith(importStep: ImportSteps.scanningWallets));
  }

  Future _updateWalletDetailsForSelection() async {
    try {
      final type = state.importType;

      final wallets = <Wallet>[];
      final network = settingsCubit.state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;

      switch (type) {
        case ImportTypes.words:
          final mnemonic = state.words.join(' ');
          final passphrase = state.passPhrase.isEmpty ? '' : state.passPhrase;

          final (ws, wErrs) = await walletSensCreate.allFromBIP39(
            mnemonic,
            passphrase,
            network,
            true,
          );
          if (wErrs != null) {
            emit(state.copyWith(errImporting: 'Error creating Wallets from Bip 39'));
            return;
          }
          wallets.addAll(ws!);

        case ImportTypes.xpub:
          if (state.xpub.contains('[')) {
            // has origin info
            final (wxpub, wErrs) = await walletCreate.oneFromXpubWithOrigin(
              state.xpub,
            );
            if (wErrs != null) {
              emit(state.copyWith(errImporting: 'Error creating Wallets from Xpub'));
              return;
            }
            wallets.addAll([wxpub!]);
          } else {
            final (wxpub, wErrs) = await walletCreate.oneFromSlip132Pub(
              state.xpub,
            );
            if (wErrs != null) {
              emit(state.copyWith(errImporting: 'Error creating Wallets from Xpub'));
              return;
            }
            wallets.addAll([wxpub!]);
          }
        case ImportTypes.coldcard:
          final coldcard = state.coldCard!;

          final (cws, wErrs) = await walletCreate.allFromColdCard(
            coldcard,
            network,
          );
          if (wErrs != null) {
            emit(state.copyWith(errImporting: 'Error creating Wallets from ColdCard'));
            return;
          }
          wallets.addAll(cws!);

        default:
          break;
      }

      if (wallets.isEmpty) throw 'Unable to create a wallet';

      emit(state.copyWith(walletDetails: wallets));
    } catch (e) {
      emit(state.copyWith(errImporting: e.toString()));
    }
  }

  void syncingComplete() {
    emit(
      state.copyWith(
        importStep: ImportSteps.selectWalletFormat,
      ),
    );
  }

  void scriptTypeChanged(ScriptType scriptType) {
    emit(state.copyWith(scriptType: scriptType));
  }

  void saveClicked() async {
    emit(state.copyWith(savingWallet: true, errSavingWallet: ''));
    final selectedWallet = state.getSelectWalletDetails();
    final network = settingsCubit.state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet;

    if (selectedWallet!.type == BBWalletType.words) {
      final mnemonic = state.words.join(' ');
      final (seed, sErr) = await walletSensCreate.mnemonicSeed(mnemonic, network);
      if (sErr != null) {
        emit(state.copyWith(errImporting: 'Error creating mnemonicSeed'));
      }
      final err = await walletSensRepository.newSeed(seed: seed!, secureStore: secureStorage);

      if (err != null) {
        emit(
          state.copyWith(
            errSavingWallet: err.toString(),
            savingWallet: false,
          ),
        );
        return;
      }

      if (state.passPhrase.isNotEmpty) {
        final passPhrase = state.passPhrase.isEmpty ? '' : state.passPhrase;

        final passphrase =
            Passphrase(passphrase: passPhrase, sourceFingerprint: selectedWallet.sourceFingerprint);

        final err = await walletSensRepository.newPassphrase(
          passphrase: passphrase,
          secureStore: secureStorage,
          seedFingerprintIndex: selectedWallet.sourceFingerprint,
        );

        if (err != null) {
          emit(
            state.copyWith(
              errSavingWallet: err.toString(),
              savingWallet: false,
            ),
          );
          return;
        }
      }
    }

    final err = await walletRepository.newWallet(
      wallet: selectedWallet,
      hiveStore: hiveStorage,
    );

    if (err != null) {
      emit(
        state.copyWith(
          errSavingWallet: err.toString(),
          savingWallet: false,
        ),
      );
    } else {
      emit(
        state.copyWith(
          savingWallet: false,
          savedWallet: selectedWallet,
        ),
      );
      clearSensitive();
    }
  }

  void clearSensitive() async {
    emit(
      state.copyWith(
        words: [],
        passPhrase: '',
      ),
    );
  }
}
