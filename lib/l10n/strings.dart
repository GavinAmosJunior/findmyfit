import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../models/garment.dart';
import '../models/laundry_batch.dart';

/// All user-facing text, in English and Bahasa Indonesia.
///
/// Usage: `S.of(context).closet`. The language follows the app setting,
/// which defaults to the phone's language.
class S {
  final bool _id;
  final String localeName;

  const S._(this._id, this.localeName);

  static const supported = [Locale('en'), Locale('id')];

  static S of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'id' ? const S._(true, 'id') : const S._(false, 'en');
  }

  String _t(String en, String id) => _id ? id : en;

  // ------------------------------------------------------------- navigation
  String get closet => _t('Closet', 'Lemari');
  String get hamper => _t('Hamper', 'Keranjang');
  String get laundry => _t('Laundry', 'Laundry');
  String get missing => _t('Missing', 'Hilang');
  String get fits => _t('Fits', 'Gaya');
  String get settings => _t('Settings', 'Pengaturan');

  // ---------------------------------------------------------------- general
  String get cancel => _t('Cancel', 'Batal');
  String get save => _t('Save', 'Simpan');
  String get done => _t('Done', 'Selesai');
  String get undo => _t('Undo', 'Urungkan');
  String get edit => _t('Edit', 'Ubah');
  String get delete => _t('Delete', 'Hapus');
  String get search => _t('Search', 'Cari');
  String get searchClothes => _t('Search clothes', 'Cari pakaian');
  String get all => _t('All', 'Semua');
  String get favorites => _t('Favorites', 'Favorit');
  String get optional => _t('Optional', 'Opsional');

  String items(int n) => _id ? '$n item' : (n == 1 ? '1 item' : '$n items');

  String date(DateTime d) => DateFormat.MMMd(localeName).format(d);

  // ----------------------------------------------------------------- status
  String statusLabel(GarmentStatus s) {
    switch (s) {
      case GarmentStatus.closet:
        return _t('Clean', 'Bersih');
      case GarmentStatus.dirtyHamper:
        return _t('In hamper', 'Di keranjang');
      case GarmentStatus.inLaundry:
        return _t('At laundry', 'Di laundry');
      case GarmentStatus.missing:
        return _t('Missing', 'Hilang');
    }
  }

  String categoryLabel(GarmentCategory c) {
    switch (c) {
      case GarmentCategory.tops:
        return _t('Tops', 'Atasan');
      case GarmentCategory.bottoms:
        return _t('Bottoms', 'Bawahan');
      case GarmentCategory.outerwear:
        return _t('Outerwear', 'Luaran');
      case GarmentCategory.delicates:
        return _t('Delicates', 'Halus');
    }
  }

  // ----------------------------------------------------------------- closet
  String closetSummary(int clean, int hamper, int laundry) => _id
      ? '$clean bersih · $hamper di keranjang · $laundry di laundry'
      : '$clean clean · $hamper in hamper · $laundry at laundry';
  String get woreIt => _t('Wore it', 'Sudah dipakai');
  String woreItHint(String name) => _t('Wore $name — move to hamper', 'Pakai $name — pindah ke keranjang');
  String movedToHamper(String name) => _t('$name is in the hamper', '$name masuk keranjang');
  String get addClothes => _t('Add clothes', 'Tambah pakaian');
  String get emptyClosetTitle => _t('Start your closet', 'Mulai isi lemarimu');
  String get emptyClosetBody =>
      _t('Snap a photo of each piece you send to the laundry, so you can check it comes back.',
          'Foto setiap pakaian yang kamu kirim ke laundry, supaya bisa dicek saat kembali.');
  String get noMatches => _t('No clothes match', 'Tidak ada yang cocok');
  String get noMatchesBody => _t('Try another search or filter.', 'Coba kata kunci atau filter lain.');
  String get favorite => _t('Favorite', 'Favorit');
  String get unfavorite => _t('Remove from favorites', 'Hapus dari favorit');
  String get putBackClean => _t('Put back clean', 'Kembalikan ke lemari');
  String get moveToHamper => _t('Move to hamper', 'Pindah ke keranjang');
  String removed(String name) => _t('$name deleted', '$name dihapus');
  String timesWorn(int n) => _id ? 'Dipakai $n kali' : (n == 1 ? 'Worn once' : 'Worn $n times');
  String lastWorn(String date) => _t('Last worn $date', 'Terakhir dipakai $date');
  String get neverWorn => _t('Not worn yet', 'Belum pernah dipakai');
  String get brand => _t('Brand', 'Merek');
  String get notes => _t('Notes', 'Catatan');
  String get category => _t('Category', 'Kategori');
  String get name => _t('Name', 'Nama');

  // ------------------------------------------------------- leaving a form
  String get discardPieceTitle => _t('Discard this piece?', 'Buang pakaian ini?');
  String get discardPieceBody =>
      _t('The photo and details you entered will be lost.', 'Foto dan detail yang kamu isi akan hilang.');
  String get discardChangesTitle => _t('Discard your changes?', 'Buang perubahanmu?');
  String get discard => _t('Discard', 'Buang');
  String get keepEditing => _t('Keep editing', 'Lanjut mengisi');

  // ------------------------------------------------------------ fit shuffle
  String get fitShuffle => 'Fit Shuffle';
  String get shuffle => _t('Shuffle', 'Acak');
  String get saveFit => _t('Save fit', 'Simpan fit');
  String get unsaveFit => _t('Remove saved fit', 'Hapus fit tersimpan');
  String get savedFits => _t('Saved fits', 'Fit tersimpan');
  String lockRail(String rail) => _t('Lock $rail', 'Kunci $rail');
  String unlockRail(String rail) => _t('Unlock $rail', 'Buka kunci $rail');
  String get shuffleEmptyTitle => _t('Not enough clean clothes', 'Pakaian bersih belum cukup');
  String get shuffleEmptyBody => _t(
      'Fit Shuffle mixes your clean tops and bottoms. Have at least one of each in the closet.',
      'Fit Shuffle memadukan atasan dan bawahan yang bersih. Butuh minimal satu dari masing-masing di lemari.');
  String get fitNotReady =>
      _t('Some pieces in that fit aren’t clean right now', 'Ada pakaian di fit itu yang belum bersih');

  // ----------------------------------------------------------------- hamper
  String get emptyHamperTitle => _t('Hamper is empty', 'Keranjang kosong');
  String get emptyHamperBody =>
      _t('Tap “Wore it” on clothes in your closet and they land here.',
          'Ketuk “Sudah dipakai” di lemari, pakaiannya akan masuk ke sini.');
  String hamperSubtitle(int total, int selected) => _id
      ? '$total item kotor · $selected dipilih'
      : '$total dirty ${total == 1 ? 'item' : 'items'} · $selected selected';
  String get selectAll => _t('Select all', 'Pilih semua');
  String get selectNone => _t('Select none', 'Batal pilih');
  String dropOff(int n) => _id ? 'Antar $n item' : 'Drop off ${items(n)}';
  String get selectToSend => _t('Select clothes to drop off', 'Pilih pakaian untuk diantar');
  String dropOffTitle(int number) => _t('Drop off load $number', 'Antar cucian $number');
  String get laundromat => _t('Laundromat', 'Tempat laundry');
  String get laundromatOptional => _t('Laundromat (optional)', 'Tempat laundry (opsional)');
  String get laundromatHint => _t('Sparkle Clean', 'Laundry Bersih Jaya');
  String get loadNickname => _t('Name this load (optional)', 'Nama cucian (opsional)');
  String get loadNicknameHint => _t('Bedsheets, work shirts…', 'Sprei, kemeja kerja…');
  String atPlace(String place) => _t('at $place', 'di $place');
  String get change => _t('Change', 'Ubah');
  String droppedOff(String load, int n) => _id ? '$load diantar · $n item' : '$load dropped off · ${items(n)}';
  String get editLoad => _t('Edit load', 'Ubah cucian');

  /// "Load 3", or its nickname when it has one.
  String loadName(LaundryBatch b) => b.hasNickname ? b.nickname!.trim() : loadNo(b.number);
  String loadNo(int n) => _t('Load $n', 'Cucian $n');

  /// "at Sparkle Clean · Sent Nov 18", or just the date with no place.
  String loadLine(LaundryBatch b) => [
        if (b.laundromatName.isNotEmpty) atPlace(b.laundromatName),
        sentOn(date(b.createdAt)),
      ].join(' · ');
  String get swipePutBack => _t('Put back', 'Kembalikan');
  String putBackHint(String name) => _t('Put $name back in the closet', 'Kembalikan $name ke lemari');

  // ---------------------------------------------------------------- laundry
  String get emptyLaundryTitle => _t('Nothing at the laundry', 'Tidak ada di laundry');
  String get emptyLaundryBody =>
      _t('When you send clothes from the hamper, check them off here as they come back.',
          'Saat kamu kirim pakaian dari keranjang, centang di sini ketika kembali.');
  String get atLaundryNow => _t('At the laundry now', 'Sedang di laundry');
  String get history => _t('History', 'Riwayat');
  String sentOn(String date) => _t('Sent $date', 'Dikirim $date');
  String backCount(int back, int total) => _id ? '$back dari $total kembali' : '$back of $total back';
  String get checkReturn => _t('Check what came back', 'Cek yang sudah kembali');
  String get tickAsBack => _t('Tick each piece as it comes back', 'Centang tiap pakaian yang sudah kembali');
  String get allBack => _t('All back', 'Semua kembali');
  String stampMissing(int n) => _t('$n missing', '$n hilang');
  String ticketNo(String code) => _t('No. $code', 'No. $code');
  String get finishReturn => _t('Finish check', 'Selesai cek');
  String get finishAllBackTitle => _t('Everything came back', 'Semua sudah kembali');
  String finishMissingTitle(int n) =>
      _id ? '$n item belum kembali' : '$n ${n == 1 ? 'piece hasn’t' : 'pieces haven’t'} come back';
  String finishMissingBody(int n) => _id
      ? 'Pakaian itu akan dipindah ke Hilang supaya bisa kamu tanyakan ke laundry.'
      : '${n == 1 ? 'It’ll' : 'They’ll'} move to Missing so you can follow up with the laundromat.';
  String get finishAllBackBody => _t('All clothes go back to your closet.', 'Semua pakaian kembali ke lemari.');
  String get keepChecking => _t('Keep checking', 'Lanjut cek');
  String get moveToMissing => _t('Move to Missing', 'Pindah ke Hilang');
  String get cancelBatch => _t('Cancel this load', 'Batalkan cucian ini');
  String get cancelBatchTitle => _t('Cancel this load?', 'Batalkan cucian ini?');
  String get cancelBatchBody =>
      _t('The clothes go back to your hamper.', 'Pakaiannya kembali ke keranjang.');
  String get keepBatch => _t('Keep load', 'Simpan cucian');
  /// [stillMissing] counts pieces not found since, so history stays true
  /// after "Found it".
  String historySummary(int sent, int stillMissing) {
    final back = sent - stillMissing;
    if (_id) return '$sent dikirim · $back kembali${stillMissing > 0 ? ' · $stillMissing hilang' : ''}';
    return '$sent sent · $back back${stillMissing > 0 ? ' · $stillMissing missing' : ''}';
  }

  // ---------------------------------------------------------------- missing
  String get missingSubtitle => _t('Didn’t come back from the laundry', 'Belum kembali dari laundry');
  String get emptyMissingTitle => _t('Everything’s accounted for', 'Semua lengkap');
  String get emptyMissingBody =>
      _t('Clothes that don’t come back from the laundry show up here.',
          'Pakaian yang tidak kembali dari laundry akan muncul di sini.');
  String get foundIt => _t('Found it', 'Sudah ketemu');
  String get lostForGood => _t('Lost for good', 'Hilang permanen');
  String lostTitle(String name) => _t('Delete $name?', 'Hapus $name?');
  String get lostBody =>
      _t('It will be removed from your wardrobe. This can’t be undone.',
          'Pakaian ini akan dihapus dari lemarimu. Tindakan ini tidak bisa dibatalkan.');
  String foundMessage(String name) => _t('$name is back in your closet', '$name kembali ke lemari');

  String get askLaundromat => _t('Ask the laundromat', 'Tanya ke laundry');
  /// [place] may be empty when the load has no laundromat set.
  String askMessage(String place, List<String> names) {
    final hi = place.isEmpty ? (_id ? 'Halo' : 'Hi') : (_id ? 'Halo $place' : 'Hi $place');
    return _askMessage(hi, names);
  }

  String _askMessage(String hi, List<String> names) => _id
      ? '$hi, pakaian berikut belum kembali dari laundry saya:\n${names.map((n) => '• $n').join('\n')}\nMohon dicek ya, terima kasih!'
      : names.length == 1
          ? '$hi, this item didn’t come back with my laundry:\n• ${names.single}\nCould you check for it? Thank you!'
          : '$hi, these items didn’t come back with my laundry:\n${names.map((n) => '• $n').join('\n')}\nCould you check for them? Thank you!';

  // -------------------------------------------------------------------- add
  String get takePhoto => _t('Take photo', 'Ambil foto');
  String get choosePhotos => _t('Choose photos', 'Pilih foto');
  String get addPhoto => _t('Add photo', 'Tambah foto');
  String get changePhoto => _t('Change photo', 'Ganti foto');
  String get nameHint => _t('Blue denim jacket', 'Jaket denim biru');
  String get nameRequired => _t('Give it a name', 'Beri nama dulu');
  String get alreadyDirty => _t('It’s dirty — put in hamper', 'Kotor — masukkan ke keranjang');
  String get add => _t('Add', 'Tambah');
  String get addAndNext => _t('Add and next', 'Tambah lalu lanjut');
  String addedCount(int n) => _id ? '$n ditambahkan' : '$n added';
  String added(String name) => _t('$name added', '$name ditambahkan');
  String queueProgress(int current, int total) => _id ? 'Foto $current dari $total' : 'Photo $current of $total';
  String get skip => _t('Skip', 'Lewati');
  String get liftingOut => _t('Removing background…', 'Menghapus latar…');
  String get rotate => _t('Rotate', 'Putar');
  String get showOriginal => _t('Show original photo', 'Tampilkan foto asli');
  String get showCutout => _t('Remove background', 'Hapus latar');
  String get cutoutFailed => _t('Background removal didn’t work on this phone. The photo is kept as is.',
      'Penghapus latar tidak berjalan di ponsel ini. Foto tetap dipakai apa adanya.');
  String get cutoutNotReady => _t('Background removal is still getting ready on this phone. Try again in a minute.',
      'Penghapus latar belum siap di ponsel ini. Coba lagi sebentar lagi.');
  String get noCutout => _t('Couldn’t find the clothes in this photo. Try a plain surface.',
      'Pakaian tidak terdeteksi di foto ini. Coba alas polos.');
  String get addFromGallery => _t('Add from gallery', 'Tambah dari galeri');
  String get editGarment => _t('Edit clothes', 'Ubah pakaian');

  // ---------------------------------------------------------------- widgets
  String get todaysFit => _t('Today’s fit', 'Gaya hari ini');
  String get anotherFit => _t('Show another fit', 'Tampilkan gaya lain');
  String get atTheLaundry => _t('At the laundry', 'Di laundry');
  String moreLoads(int n) => _t('+$n more', '+$n lagi');

  // --------------------------------------------------------- all cutouts
  String get photos => _t('Photos', 'Foto');
  String get removeBackgrounds => _t('Remove backgrounds', 'Hapus latar foto');
  String cutoutAllCount(int n) => _id
      ? '$n foto bisa dibuat rapi'
      : (n == 1 ? '1 photo can get the clean look' : '$n photos can get the clean look');
  String get cutoutAllNone => _t('Every photo has the clean look', 'Semua foto sudah rapi');
  String cutoutAllProgress(int i, int n) => _id ? 'Memproses $i dari $n…' : 'Working on $i of $n…';
  String cutoutAllTitle(int n) =>
      _id ? 'Hapus latar dari $n foto?' : (n == 1 ? 'Remove the background from 1 photo?' : 'Remove backgrounds from $n photos?');
  String get cutoutAllBody => _t(
      'Each piece is lifted onto a clean backdrop, like a product photo. The original photos are replaced.',
      'Setiap pakaian dipindah ke latar bersih, seperti foto produk. Foto asli akan diganti.');
  String cutoutAllDone(int done, int skipped) {
    if (_id) return skipped == 0 ? '$done foto diperbarui' : '$done foto diperbarui · $skipped tidak terdeteksi';
    final updated = done == 1 ? '1 photo updated' : '$done photos updated';
    return skipped == 0 ? updated : '$updated · $skipped had no clear piece';
  }

  String get photosFooter => _t('The first time needs internet, to download Google’s background remover.',
      'Pertama kali butuh internet, untuk mengunduh penghapus latar dari Google.');
  String get photoError => _t('Couldn’t open the camera or photos. Check app permissions.',
      'Tidak bisa membuka kamera atau galeri. Cek izin aplikasi.');

  // --------------------------------------------------------------- settings
  String get appearance => _t('Appearance', 'Tampilan');
  String get light => _t('Light', 'Terang');
  String get dark => _t('Dark', 'Gelap');
  String get language => _t('Language', 'Bahasa');
  String get systemLanguage => _t('Same as phone', 'Sama dengan ponsel');
  String get backup => _t('Backup', 'Cadangan');
  String get backupFooter =>
      _t('Your clothes and photos are saved only on this phone. Export a backup file to keep them safe.',
          'Pakaian dan foto hanya tersimpan di ponsel ini. Ekspor file cadangan agar tetap aman.');
  String get exportBackup => _t('Export backup', 'Ekspor cadangan');
  String get importBackup => _t('Import backup', 'Impor cadangan');
  String get importTitle => _t('Replace everything with this backup?', 'Ganti semua data dengan cadangan ini?');
  String importBody(int n) => _id
      ? 'Cadangan berisi $n pakaian. Data di ponsel ini akan diganti dan tidak bisa dikembalikan.'
      : 'The backup has ${items(n)}. Everything on this phone will be replaced, and this can’t be undone.';
  String get replace => _t('Replace', 'Ganti');
  String get importDone => _t('Backup restored', 'Cadangan dipulihkan');
  String get importFailed => _t('That file isn’t a FindMyFit backup.', 'File itu bukan cadangan FindMyFit.');
  String get exportFailed => _t('Couldn’t export the backup. Try again.', 'Gagal mengekspor cadangan. Coba lagi.');
  String get about => _t('About', 'Tentang');
  String get aboutBody =>
      _t('FindMyFit helps you check that everything you send to the laundry comes back.',
          'FindMyFit membantu memastikan semua pakaian yang kamu kirim ke laundry kembali.');
}
