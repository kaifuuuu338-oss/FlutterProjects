import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:my_first_app/models/referral_model.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'api_service.dart';
import 'local_db_service.dart';

class SyncService {
  final Connectivity _connectivity = Connectivity();
  final APIService _apiService = APIService();
  final LocalDBService _localDBService;

  SyncService(this._localDBService);

  /// Check internet connection
  Future<bool> hasInternetConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result == ConnectivityResult.wifi || result == ConnectivityResult.mobile;
  }

  /// Sync unsynced screenings
  Future<void> syncPendingScreenings() async {
    if (!await hasInternetConnection()) {
      print('No internet connection. Sync skipped.');
      return;
    }

    try {
      List<ScreeningModel> unsyncedScreenings = _localDBService.getUnsyncedScreenings();

      for (var screening in unsyncedScreenings) {
        try {
          await _apiService.submitScreening(screening.toJson());

          // Update screening as synced
          ScreeningModel syncedScreening = screening.copyWith(
            submittedAt: DateTime.now(),
          );
          await _localDBService.saveScreening(syncedScreening);

          print('Screening ${screening.screeningId} synced successfully.');
        } catch (e) {
          print('Error syncing screening ${screening.screeningId}: $e');
        }
      }

      // Sync unsynced referrals
      List<ReferralModel> unsyncedReferrals = _localDBService.getUnsyncedReferrals();
      for (var referral in unsyncedReferrals) {
        try {
          await _apiService.createReferral(referral.toJson());
          final syncedReferral = referral.copyWith(
            metadata: {
              ...(referral.metadata ?? <String, dynamic>{}),
              'sync_status': 'synced',
            },
          );
          await _localDBService.saveReferral(syncedReferral);
          print('Referral ${referral.referralId} synced successfully.');
        } catch (e) {
          print('Error syncing referral ${referral.referralId}: $e');
        }
      }
    } catch (e) {
      print('Sync error: $e');
    }
  }

  /// Listen for connectivity changes and auto-sync
  void listenForConnectivityChanges() {
    _connectivity.onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.wifi || result == ConnectivityResult.mobile) {
        print('Internet restored. Starting sync...');
        await syncPendingScreenings();
      }
    });
  }
}
