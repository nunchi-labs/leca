import 'package:chow/compliance.dart';
import 'package:chow/location.dart';
import 'package:chow/market.dart';
import 'package:chow/state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trained = (
    independentPartner: true,
    trainedTrafficLaw: true,
    trainedDriving: true,
    trainedService: true,
    trainedConduct: true,
    logoOnVehicle: true,
    licenceNumber: 'PP12345',
    plate: '2B-1001',
    registration: 'REG-9',
    inspection: 'INS-9',
    domesticCert: 'DOM-9',
    insurance: 'POL-9',
  );

  String? check(
    String kind, {
    String inspection = 'INS-9',
    String domestic = 'DOM-9',
  }) {
    return CambodiaRules.checkPartner(
      vehicleKind: kind,
      licenceNumber: trained.licenceNumber,
      plate: trained.plate,
      registration: trained.registration,
      inspection: inspection,
      domesticCert: domestic,
      insurance: trained.insurance,
      logoOnVehicle: trained.logoOnVehicle,
      independentPartner: trained.independentPartner,
      trainedTrafficLaw: trained.trainedTrafficLaw,
      trainedDriving: trained.trainedDriving,
      trainedService: trained.trainedService,
      trainedConduct: trained.trainedConduct,
    );
  }

  test('vehicle papers follow the hailing exemptions', () {
    expect(check('motorcycle', inspection: '', domestic: ''), isNull);
    expect(check('tuktuk', domestic: ''), isNull);
    expect(check('remorque', domestic: ''), isNull);
    expect(check('tuktuk', inspection: ''), 'inspection_invalid');
    expect(check('car', domestic: ''), 'transport_cert_invalid');
    expect(check('car', inspection: ''), 'inspection_invalid');
    expect(check('bicycle', inspection: '', domestic: ''), isNull);
  });

  test(
    'a platform fleet and a missing owner are rejected in Cambodia',
    () async {
      final state = ChowState();
      await state.listVehicle(
        kind: 'car',
        withDriver: false,
        autonomous: true,
        owner: true,
      );
      expect(state.supplyError, 'platform_fleet');
      expect(state.vehicles, isEmpty);
      await state.listVehicle(
        kind: 'boat',
        withDriver: true,
        autonomous: false,
      );
      expect(state.supplyError, 'owner_required');
    },
  );

  test(
    'a safety report suspends the partner and a share carries the fix',
    () async {
      final state = ChowState();
      state.setBooking(
        const Booking(
          kind: BookKind.ride,
          title: 'Motorcycle',
          amountUsd: 1.2,
          vehicleId: 'motorcycle',
        ),
      );
      state.syncRideMatch();
      expect(state.rideMatch?.plate, '2A-4521');

      TripLocation.override = () async =>
          const TripFix(latitude: 11.55637, longitude: 104.92821);
      addTearDown(() => TripLocation.override = null);
      final shared = await state.shareTrip('family');
      expect(shared, contains('For: family'));
      expect(shared, contains('Plate: 2A-4521'));
      expect(shared, contains('Location: 11.55637, 104.92821'));
      expect(state.shares.single.hasLocation, isTrue);

      TripLocation.override = () async => null;
      final missing = await state.shareTrip('authorities');
      expect(missing, contains('Location: unavailable'));
      expect(missing, contains('For: authorities'));

      final reported = state.rideMatch!.id;
      state.fileSafetyReport('harassment');
      expect(state.reports.single.status, 'acted');
      expect(state.reports.single.category, 'harassment');
      expect(state.suspendedPartnerIds, contains(reported));
      expect(state.rideMatch?.id, isNot(reported));
    },
  );
}
