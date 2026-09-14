// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $KategoriTable extends Kategori
    with TableInfo<$KategoriTable, KategoriData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KategoriTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _namaMeta = const VerificationMeta('nama');
  @override
  late final GeneratedColumn<String> nama = GeneratedColumn<String>(
    'nama',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ikonMeta = const VerificationMeta('ikon');
  @override
  late final GeneratedColumn<String> ikon = GeneratedColumn<String>(
    'ikon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('receipt'),
  );
  static const VerificationMeta _warnaMeta = const VerificationMeta('warna');
  @override
  late final GeneratedColumn<String> warna = GeneratedColumn<String>(
    'warna',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#4A90D9'),
  );
  static const VerificationMeta _urutanMeta = const VerificationMeta('urutan');
  @override
  late final GeneratedColumn<int> urutan = GeneratedColumn<int>(
    'urutan',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, nama, ikon, warna, urutan];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kategori';
  @override
  VerificationContext validateIntegrity(
    Insertable<KategoriData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('ikon')) {
      context.handle(
        _ikonMeta,
        ikon.isAcceptableOrUnknown(data['ikon']!, _ikonMeta),
      );
    }
    if (data.containsKey('warna')) {
      context.handle(
        _warnaMeta,
        warna.isAcceptableOrUnknown(data['warna']!, _warnaMeta),
      );
    }
    if (data.containsKey('urutan')) {
      context.handle(
        _urutanMeta,
        urutan.isAcceptableOrUnknown(data['urutan']!, _urutanMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KategoriData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KategoriData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      ikon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ikon'],
      )!,
      warna: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}warna'],
      )!,
      urutan: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}urutan'],
      )!,
    );
  }

  @override
  $KategoriTable createAlias(String alias) {
    return $KategoriTable(attachedDatabase, alias);
  }
}

class KategoriData extends DataClass implements Insertable<KategoriData> {
  final int id;
  final String nama;
  final String ikon;
  final String warna;
  final int urutan;
  const KategoriData({
    required this.id,
    required this.nama,
    required this.ikon,
    required this.warna,
    required this.urutan,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nama'] = Variable<String>(nama);
    map['ikon'] = Variable<String>(ikon);
    map['warna'] = Variable<String>(warna);
    map['urutan'] = Variable<int>(urutan);
    return map;
  }

  KategoriCompanion toCompanion(bool nullToAbsent) {
    return KategoriCompanion(
      id: Value(id),
      nama: Value(nama),
      ikon: Value(ikon),
      warna: Value(warna),
      urutan: Value(urutan),
    );
  }

  factory KategoriData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KategoriData(
      id: serializer.fromJson<int>(json['id']),
      nama: serializer.fromJson<String>(json['nama']),
      ikon: serializer.fromJson<String>(json['ikon']),
      warna: serializer.fromJson<String>(json['warna']),
      urutan: serializer.fromJson<int>(json['urutan']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nama': serializer.toJson<String>(nama),
      'ikon': serializer.toJson<String>(ikon),
      'warna': serializer.toJson<String>(warna),
      'urutan': serializer.toJson<int>(urutan),
    };
  }

  KategoriData copyWith({
    int? id,
    String? nama,
    String? ikon,
    String? warna,
    int? urutan,
  }) => KategoriData(
    id: id ?? this.id,
    nama: nama ?? this.nama,
    ikon: ikon ?? this.ikon,
    warna: warna ?? this.warna,
    urutan: urutan ?? this.urutan,
  );
  KategoriData copyWithCompanion(KategoriCompanion data) {
    return KategoriData(
      id: data.id.present ? data.id.value : this.id,
      nama: data.nama.present ? data.nama.value : this.nama,
      ikon: data.ikon.present ? data.ikon.value : this.ikon,
      warna: data.warna.present ? data.warna.value : this.warna,
      urutan: data.urutan.present ? data.urutan.value : this.urutan,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KategoriData(')
          ..write('id: $id, ')
          ..write('nama: $nama, ')
          ..write('ikon: $ikon, ')
          ..write('warna: $warna, ')
          ..write('urutan: $urutan')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nama, ikon, warna, urutan);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KategoriData &&
          other.id == this.id &&
          other.nama == this.nama &&
          other.ikon == this.ikon &&
          other.warna == this.warna &&
          other.urutan == this.urutan);
}

class KategoriCompanion extends UpdateCompanion<KategoriData> {
  final Value<int> id;
  final Value<String> nama;
  final Value<String> ikon;
  final Value<String> warna;
  final Value<int> urutan;
  const KategoriCompanion({
    this.id = const Value.absent(),
    this.nama = const Value.absent(),
    this.ikon = const Value.absent(),
    this.warna = const Value.absent(),
    this.urutan = const Value.absent(),
  });
  KategoriCompanion.insert({
    this.id = const Value.absent(),
    required String nama,
    this.ikon = const Value.absent(),
    this.warna = const Value.absent(),
    this.urutan = const Value.absent(),
  }) : nama = Value(nama);
  static Insertable<KategoriData> custom({
    Expression<int>? id,
    Expression<String>? nama,
    Expression<String>? ikon,
    Expression<String>? warna,
    Expression<int>? urutan,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nama != null) 'nama': nama,
      if (ikon != null) 'ikon': ikon,
      if (warna != null) 'warna': warna,
      if (urutan != null) 'urutan': urutan,
    });
  }

  KategoriCompanion copyWith({
    Value<int>? id,
    Value<String>? nama,
    Value<String>? ikon,
    Value<String>? warna,
    Value<int>? urutan,
  }) {
    return KategoriCompanion(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      ikon: ikon ?? this.ikon,
      warna: warna ?? this.warna,
      urutan: urutan ?? this.urutan,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (ikon.present) {
      map['ikon'] = Variable<String>(ikon.value);
    }
    if (warna.present) {
      map['warna'] = Variable<String>(warna.value);
    }
    if (urutan.present) {
      map['urutan'] = Variable<int>(urutan.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KategoriCompanion(')
          ..write('id: $id, ')
          ..write('nama: $nama, ')
          ..write('ikon: $ikon, ')
          ..write('warna: $warna, ')
          ..write('urutan: $urutan')
          ..write(')'))
        .toString();
  }
}

class $TagihanTable extends Tagihan with TableInfo<$TagihanTable, TagihanData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagihanTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _jenisMeta = const VerificationMeta('jenis');
  @override
  late final GeneratedColumn<String> jenis = GeneratedColumn<String>(
    'jenis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('tagihan'),
  );
  static const VerificationMeta _namaMeta = const VerificationMeta('nama');
  @override
  late final GeneratedColumn<String> nama = GeneratedColumn<String>(
    'nama',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jumlahSenMeta = const VerificationMeta(
    'jumlahSen',
  );
  @override
  late final GeneratedColumn<int> jumlahSen = GeneratedColumn<int>(
    'jumlah_sen',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kodeMataUangMeta = const VerificationMeta(
    'kodeMataUang',
  );
  @override
  late final GeneratedColumn<String> kodeMataUang = GeneratedColumn<String>(
    'kode_mata_uang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('IDR'),
  );
  static const VerificationMeta _kategoriIdMeta = const VerificationMeta(
    'kategoriId',
  );
  @override
  late final GeneratedColumn<int> kategoriId = GeneratedColumn<int>(
    'kategori_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES kategori (id)',
    ),
  );
  static const VerificationMeta _jatuhTempoMeta = const VerificationMeta(
    'jatuhTempo',
  );
  @override
  late final GeneratedColumn<DateTime> jatuhTempo = GeneratedColumn<DateTime>(
    'jatuh_tempo',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frekuensiMeta = const VerificationMeta(
    'frekuensi',
  );
  @override
  late final GeneratedColumn<String> frekuensi = GeneratedColumn<String>(
    'frekuensi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('bulanan'),
  );
  static const VerificationMeta _kustomHariNMeta = const VerificationMeta(
    'kustomHariN',
  );
  @override
  late final GeneratedColumn<int> kustomHariN = GeneratedColumn<int>(
    'kustom_hari_n',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pengingatLeadHariMeta = const VerificationMeta(
    'pengingatLeadHari',
  );
  @override
  late final GeneratedColumn<String> pengingatLeadHari =
      GeneratedColumn<String>(
        'pengingat_lead_hari',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('7,3,1'),
      );
  static const VerificationMeta _pengingatJamMeta = const VerificationMeta(
    'pengingatJam',
  );
  @override
  late final GeneratedColumn<String> pengingatJam = GeneratedColumn<String>(
    'pengingat_jam',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('09:00'),
  );
  static const VerificationMeta _kanalPengingatMeta = const VerificationMeta(
    'kanalPengingat',
  );
  @override
  late final GeneratedColumn<String> kanalPengingat = GeneratedColumn<String>(
    'kanal_pengingat',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('push'),
  );
  static const VerificationMeta _prioritasMeta = const VerificationMeta(
    'prioritas',
  );
  @override
  late final GeneratedColumn<String> prioritas = GeneratedColumn<String>(
    'prioritas',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('biasa'),
  );
  static const VerificationMeta _catatanMeta = const VerificationMeta(
    'catatan',
  );
  @override
  late final GeneratedColumn<String> catatan = GeneratedColumn<String>(
    'catatan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tautanBayarMeta = const VerificationMeta(
    'tautanBayar',
  );
  @override
  late final GeneratedColumn<String> tautanBayar = GeneratedColumn<String>(
    'tautan_bayar',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusAktifMeta = const VerificationMeta(
    'statusAktif',
  );
  @override
  late final GeneratedColumn<bool> statusAktif = GeneratedColumn<bool>(
    'status_aktif',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("status_aktif" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lunasMeta = const VerificationMeta('lunas');
  @override
  late final GeneratedColumn<bool> lunas = GeneratedColumn<bool>(
    'lunas',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("lunas" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tanggalLunasMeta = const VerificationMeta(
    'tanggalLunas',
  );
  @override
  late final GeneratedColumn<DateTime> tanggalLunas = GeneratedColumn<DateTime>(
    'tanggal_lunas',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dibuatPadaMeta = const VerificationMeta(
    'dibuatPada',
  );
  @override
  late final GeneratedColumn<DateTime> dibuatPada = GeneratedColumn<DateTime>(
    'dibuat_pada',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _diubahPadaMeta = const VerificationMeta(
    'diubahPada',
  );
  @override
  late final GeneratedColumn<DateTime> diubahPada = GeneratedColumn<DateTime>(
    'diubah_pada',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    jenis,
    nama,
    jumlahSen,
    kodeMataUang,
    kategoriId,
    jatuhTempo,
    frekuensi,
    kustomHariN,
    pengingatLeadHari,
    pengingatJam,
    kanalPengingat,
    prioritas,
    catatan,
    tautanBayar,
    statusAktif,
    lunas,
    tanggalLunas,
    dibuatPada,
    diubahPada,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tagihan';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagihanData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('jenis')) {
      context.handle(
        _jenisMeta,
        jenis.isAcceptableOrUnknown(data['jenis']!, _jenisMeta),
      );
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('jumlah_sen')) {
      context.handle(
        _jumlahSenMeta,
        jumlahSen.isAcceptableOrUnknown(data['jumlah_sen']!, _jumlahSenMeta),
      );
    }
    if (data.containsKey('kode_mata_uang')) {
      context.handle(
        _kodeMataUangMeta,
        kodeMataUang.isAcceptableOrUnknown(
          data['kode_mata_uang']!,
          _kodeMataUangMeta,
        ),
      );
    }
    if (data.containsKey('kategori_id')) {
      context.handle(
        _kategoriIdMeta,
        kategoriId.isAcceptableOrUnknown(data['kategori_id']!, _kategoriIdMeta),
      );
    }
    if (data.containsKey('jatuh_tempo')) {
      context.handle(
        _jatuhTempoMeta,
        jatuhTempo.isAcceptableOrUnknown(data['jatuh_tempo']!, _jatuhTempoMeta),
      );
    } else if (isInserting) {
      context.missing(_jatuhTempoMeta);
    }
    if (data.containsKey('frekuensi')) {
      context.handle(
        _frekuensiMeta,
        frekuensi.isAcceptableOrUnknown(data['frekuensi']!, _frekuensiMeta),
      );
    }
    if (data.containsKey('kustom_hari_n')) {
      context.handle(
        _kustomHariNMeta,
        kustomHariN.isAcceptableOrUnknown(
          data['kustom_hari_n']!,
          _kustomHariNMeta,
        ),
      );
    }
    if (data.containsKey('pengingat_lead_hari')) {
      context.handle(
        _pengingatLeadHariMeta,
        pengingatLeadHari.isAcceptableOrUnknown(
          data['pengingat_lead_hari']!,
          _pengingatLeadHariMeta,
        ),
      );
    }
    if (data.containsKey('pengingat_jam')) {
      context.handle(
        _pengingatJamMeta,
        pengingatJam.isAcceptableOrUnknown(
          data['pengingat_jam']!,
          _pengingatJamMeta,
        ),
      );
    }
    if (data.containsKey('kanal_pengingat')) {
      context.handle(
        _kanalPengingatMeta,
        kanalPengingat.isAcceptableOrUnknown(
          data['kanal_pengingat']!,
          _kanalPengingatMeta,
        ),
      );
    }
    if (data.containsKey('prioritas')) {
      context.handle(
        _prioritasMeta,
        prioritas.isAcceptableOrUnknown(data['prioritas']!, _prioritasMeta),
      );
    }
    if (data.containsKey('catatan')) {
      context.handle(
        _catatanMeta,
        catatan.isAcceptableOrUnknown(data['catatan']!, _catatanMeta),
      );
    }
    if (data.containsKey('tautan_bayar')) {
      context.handle(
        _tautanBayarMeta,
        tautanBayar.isAcceptableOrUnknown(
          data['tautan_bayar']!,
          _tautanBayarMeta,
        ),
      );
    }
    if (data.containsKey('status_aktif')) {
      context.handle(
        _statusAktifMeta,
        statusAktif.isAcceptableOrUnknown(
          data['status_aktif']!,
          _statusAktifMeta,
        ),
      );
    }
    if (data.containsKey('lunas')) {
      context.handle(
        _lunasMeta,
        lunas.isAcceptableOrUnknown(data['lunas']!, _lunasMeta),
      );
    }
    if (data.containsKey('tanggal_lunas')) {
      context.handle(
        _tanggalLunasMeta,
        tanggalLunas.isAcceptableOrUnknown(
          data['tanggal_lunas']!,
          _tanggalLunasMeta,
        ),
      );
    }
    if (data.containsKey('dibuat_pada')) {
      context.handle(
        _dibuatPadaMeta,
        dibuatPada.isAcceptableOrUnknown(data['dibuat_pada']!, _dibuatPadaMeta),
      );
    }
    if (data.containsKey('diubah_pada')) {
      context.handle(
        _diubahPadaMeta,
        diubahPada.isAcceptableOrUnknown(data['diubah_pada']!, _diubahPadaMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagihanData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagihanData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      jenis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jenis'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      jumlahSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}jumlah_sen'],
      ),
      kodeMataUang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kode_mata_uang'],
      )!,
      kategoriId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kategori_id'],
      ),
      jatuhTempo: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}jatuh_tempo'],
      )!,
      frekuensi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frekuensi'],
      )!,
      kustomHariN: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kustom_hari_n'],
      ),
      pengingatLeadHari: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pengingat_lead_hari'],
      )!,
      pengingatJam: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pengingat_jam'],
      )!,
      kanalPengingat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kanal_pengingat'],
      )!,
      prioritas: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prioritas'],
      )!,
      catatan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catatan'],
      ),
      tautanBayar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tautan_bayar'],
      ),
      statusAktif: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}status_aktif'],
      )!,
      lunas: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}lunas'],
      )!,
      tanggalLunas: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tanggal_lunas'],
      ),
      dibuatPada: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dibuat_pada'],
      )!,
      diubahPada: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}diubah_pada'],
      )!,
    );
  }

  @override
  $TagihanTable createAlias(String alias) {
    return $TagihanTable(attachedDatabase, alias);
  }
}

class TagihanData extends DataClass implements Insertable<TagihanData> {
  final int id;
  final String jenis;
  final String nama;

  /// Jumlah dalam satuan terkecil mata uang; null untuk dokumen/non-moneter.
  final int? jumlahSen;
  final String kodeMataUang;
  final int? kategoriId;

  /// Tanggal jatuh tempo / masa berlaku.
  final DateTime jatuhTempo;
  final String frekuensi;

  /// Untuk frekuensi kustom_hari.
  final int? kustomHariN;

  /// Lead days notifikasi, teks "7,3,1".
  final String pengingatLeadHari;

  /// Jam notifikasi HH:mm.
  final String pengingatJam;
  final String kanalPengingat;
  final String prioritas;
  final String? catatan;

  /// URL/tautan pembayaran (FR-42 pusat bayar).
  final String? tautanBayar;

  /// false = nonaktif (sementara/berhenti), bukan hapus riwayat.
  final bool statusAktif;

  /// false = sudah dibayar di periode berjalan.
  final bool lunas;
  final DateTime? tanggalLunas;
  final DateTime dibuatPada;
  final DateTime diubahPada;
  const TagihanData({
    required this.id,
    required this.jenis,
    required this.nama,
    this.jumlahSen,
    required this.kodeMataUang,
    this.kategoriId,
    required this.jatuhTempo,
    required this.frekuensi,
    this.kustomHariN,
    required this.pengingatLeadHari,
    required this.pengingatJam,
    required this.kanalPengingat,
    required this.prioritas,
    this.catatan,
    this.tautanBayar,
    required this.statusAktif,
    required this.lunas,
    this.tanggalLunas,
    required this.dibuatPada,
    required this.diubahPada,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['jenis'] = Variable<String>(jenis);
    map['nama'] = Variable<String>(nama);
    if (!nullToAbsent || jumlahSen != null) {
      map['jumlah_sen'] = Variable<int>(jumlahSen);
    }
    map['kode_mata_uang'] = Variable<String>(kodeMataUang);
    if (!nullToAbsent || kategoriId != null) {
      map['kategori_id'] = Variable<int>(kategoriId);
    }
    map['jatuh_tempo'] = Variable<DateTime>(jatuhTempo);
    map['frekuensi'] = Variable<String>(frekuensi);
    if (!nullToAbsent || kustomHariN != null) {
      map['kustom_hari_n'] = Variable<int>(kustomHariN);
    }
    map['pengingat_lead_hari'] = Variable<String>(pengingatLeadHari);
    map['pengingat_jam'] = Variable<String>(pengingatJam);
    map['kanal_pengingat'] = Variable<String>(kanalPengingat);
    map['prioritas'] = Variable<String>(prioritas);
    if (!nullToAbsent || catatan != null) {
      map['catatan'] = Variable<String>(catatan);
    }
    if (!nullToAbsent || tautanBayar != null) {
      map['tautan_bayar'] = Variable<String>(tautanBayar);
    }
    map['status_aktif'] = Variable<bool>(statusAktif);
    map['lunas'] = Variable<bool>(lunas);
    if (!nullToAbsent || tanggalLunas != null) {
      map['tanggal_lunas'] = Variable<DateTime>(tanggalLunas);
    }
    map['dibuat_pada'] = Variable<DateTime>(dibuatPada);
    map['diubah_pada'] = Variable<DateTime>(diubahPada);
    return map;
  }

  TagihanCompanion toCompanion(bool nullToAbsent) {
    return TagihanCompanion(
      id: Value(id),
      jenis: Value(jenis),
      nama: Value(nama),
      jumlahSen: jumlahSen == null && nullToAbsent
          ? const Value.absent()
          : Value(jumlahSen),
      kodeMataUang: Value(kodeMataUang),
      kategoriId: kategoriId == null && nullToAbsent
          ? const Value.absent()
          : Value(kategoriId),
      jatuhTempo: Value(jatuhTempo),
      frekuensi: Value(frekuensi),
      kustomHariN: kustomHariN == null && nullToAbsent
          ? const Value.absent()
          : Value(kustomHariN),
      pengingatLeadHari: Value(pengingatLeadHari),
      pengingatJam: Value(pengingatJam),
      kanalPengingat: Value(kanalPengingat),
      prioritas: Value(prioritas),
      catatan: catatan == null && nullToAbsent
          ? const Value.absent()
          : Value(catatan),
      tautanBayar: tautanBayar == null && nullToAbsent
          ? const Value.absent()
          : Value(tautanBayar),
      statusAktif: Value(statusAktif),
      lunas: Value(lunas),
      tanggalLunas: tanggalLunas == null && nullToAbsent
          ? const Value.absent()
          : Value(tanggalLunas),
      dibuatPada: Value(dibuatPada),
      diubahPada: Value(diubahPada),
    );
  }

  factory TagihanData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagihanData(
      id: serializer.fromJson<int>(json['id']),
      jenis: serializer.fromJson<String>(json['jenis']),
      nama: serializer.fromJson<String>(json['nama']),
      jumlahSen: serializer.fromJson<int?>(json['jumlahSen']),
      kodeMataUang: serializer.fromJson<String>(json['kodeMataUang']),
      kategoriId: serializer.fromJson<int?>(json['kategoriId']),
      jatuhTempo: serializer.fromJson<DateTime>(json['jatuhTempo']),
      frekuensi: serializer.fromJson<String>(json['frekuensi']),
      kustomHariN: serializer.fromJson<int?>(json['kustomHariN']),
      pengingatLeadHari: serializer.fromJson<String>(json['pengingatLeadHari']),
      pengingatJam: serializer.fromJson<String>(json['pengingatJam']),
      kanalPengingat: serializer.fromJson<String>(json['kanalPengingat']),
      prioritas: serializer.fromJson<String>(json['prioritas']),
      catatan: serializer.fromJson<String?>(json['catatan']),
      tautanBayar: serializer.fromJson<String?>(json['tautanBayar']),
      statusAktif: serializer.fromJson<bool>(json['statusAktif']),
      lunas: serializer.fromJson<bool>(json['lunas']),
      tanggalLunas: serializer.fromJson<DateTime?>(json['tanggalLunas']),
      dibuatPada: serializer.fromJson<DateTime>(json['dibuatPada']),
      diubahPada: serializer.fromJson<DateTime>(json['diubahPada']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'jenis': serializer.toJson<String>(jenis),
      'nama': serializer.toJson<String>(nama),
      'jumlahSen': serializer.toJson<int?>(jumlahSen),
      'kodeMataUang': serializer.toJson<String>(kodeMataUang),
      'kategoriId': serializer.toJson<int?>(kategoriId),
      'jatuhTempo': serializer.toJson<DateTime>(jatuhTempo),
      'frekuensi': serializer.toJson<String>(frekuensi),
      'kustomHariN': serializer.toJson<int?>(kustomHariN),
      'pengingatLeadHari': serializer.toJson<String>(pengingatLeadHari),
      'pengingatJam': serializer.toJson<String>(pengingatJam),
      'kanalPengingat': serializer.toJson<String>(kanalPengingat),
      'prioritas': serializer.toJson<String>(prioritas),
      'catatan': serializer.toJson<String?>(catatan),
      'tautanBayar': serializer.toJson<String?>(tautanBayar),
      'statusAktif': serializer.toJson<bool>(statusAktif),
      'lunas': serializer.toJson<bool>(lunas),
      'tanggalLunas': serializer.toJson<DateTime?>(tanggalLunas),
      'dibuatPada': serializer.toJson<DateTime>(dibuatPada),
      'diubahPada': serializer.toJson<DateTime>(diubahPada),
    };
  }

  TagihanData copyWith({
    int? id,
    String? jenis,
    String? nama,
    Value<int?> jumlahSen = const Value.absent(),
    String? kodeMataUang,
    Value<int?> kategoriId = const Value.absent(),
    DateTime? jatuhTempo,
    String? frekuensi,
    Value<int?> kustomHariN = const Value.absent(),
    String? pengingatLeadHari,
    String? pengingatJam,
    String? kanalPengingat,
    String? prioritas,
    Value<String?> catatan = const Value.absent(),
    Value<String?> tautanBayar = const Value.absent(),
    bool? statusAktif,
    bool? lunas,
    Value<DateTime?> tanggalLunas = const Value.absent(),
    DateTime? dibuatPada,
    DateTime? diubahPada,
  }) => TagihanData(
    id: id ?? this.id,
    jenis: jenis ?? this.jenis,
    nama: nama ?? this.nama,
    jumlahSen: jumlahSen.present ? jumlahSen.value : this.jumlahSen,
    kodeMataUang: kodeMataUang ?? this.kodeMataUang,
    kategoriId: kategoriId.present ? kategoriId.value : this.kategoriId,
    jatuhTempo: jatuhTempo ?? this.jatuhTempo,
    frekuensi: frekuensi ?? this.frekuensi,
    kustomHariN: kustomHariN.present ? kustomHariN.value : this.kustomHariN,
    pengingatLeadHari: pengingatLeadHari ?? this.pengingatLeadHari,
    pengingatJam: pengingatJam ?? this.pengingatJam,
    kanalPengingat: kanalPengingat ?? this.kanalPengingat,
    prioritas: prioritas ?? this.prioritas,
    catatan: catatan.present ? catatan.value : this.catatan,
    tautanBayar: tautanBayar.present ? tautanBayar.value : this.tautanBayar,
    statusAktif: statusAktif ?? this.statusAktif,
    lunas: lunas ?? this.lunas,
    tanggalLunas: tanggalLunas.present ? tanggalLunas.value : this.tanggalLunas,
    dibuatPada: dibuatPada ?? this.dibuatPada,
    diubahPada: diubahPada ?? this.diubahPada,
  );
  TagihanData copyWithCompanion(TagihanCompanion data) {
    return TagihanData(
      id: data.id.present ? data.id.value : this.id,
      jenis: data.jenis.present ? data.jenis.value : this.jenis,
      nama: data.nama.present ? data.nama.value : this.nama,
      jumlahSen: data.jumlahSen.present ? data.jumlahSen.value : this.jumlahSen,
      kodeMataUang: data.kodeMataUang.present
          ? data.kodeMataUang.value
          : this.kodeMataUang,
      kategoriId: data.kategoriId.present
          ? data.kategoriId.value
          : this.kategoriId,
      jatuhTempo: data.jatuhTempo.present
          ? data.jatuhTempo.value
          : this.jatuhTempo,
      frekuensi: data.frekuensi.present ? data.frekuensi.value : this.frekuensi,
      kustomHariN: data.kustomHariN.present
          ? data.kustomHariN.value
          : this.kustomHariN,
      pengingatLeadHari: data.pengingatLeadHari.present
          ? data.pengingatLeadHari.value
          : this.pengingatLeadHari,
      pengingatJam: data.pengingatJam.present
          ? data.pengingatJam.value
          : this.pengingatJam,
      kanalPengingat: data.kanalPengingat.present
          ? data.kanalPengingat.value
          : this.kanalPengingat,
      prioritas: data.prioritas.present ? data.prioritas.value : this.prioritas,
      catatan: data.catatan.present ? data.catatan.value : this.catatan,
      tautanBayar: data.tautanBayar.present
          ? data.tautanBayar.value
          : this.tautanBayar,
      statusAktif: data.statusAktif.present
          ? data.statusAktif.value
          : this.statusAktif,
      lunas: data.lunas.present ? data.lunas.value : this.lunas,
      tanggalLunas: data.tanggalLunas.present
          ? data.tanggalLunas.value
          : this.tanggalLunas,
      dibuatPada: data.dibuatPada.present
          ? data.dibuatPada.value
          : this.dibuatPada,
      diubahPada: data.diubahPada.present
          ? data.diubahPada.value
          : this.diubahPada,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagihanData(')
          ..write('id: $id, ')
          ..write('jenis: $jenis, ')
          ..write('nama: $nama, ')
          ..write('jumlahSen: $jumlahSen, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('kategoriId: $kategoriId, ')
          ..write('jatuhTempo: $jatuhTempo, ')
          ..write('frekuensi: $frekuensi, ')
          ..write('kustomHariN: $kustomHariN, ')
          ..write('pengingatLeadHari: $pengingatLeadHari, ')
          ..write('pengingatJam: $pengingatJam, ')
          ..write('kanalPengingat: $kanalPengingat, ')
          ..write('prioritas: $prioritas, ')
          ..write('catatan: $catatan, ')
          ..write('tautanBayar: $tautanBayar, ')
          ..write('statusAktif: $statusAktif, ')
          ..write('lunas: $lunas, ')
          ..write('tanggalLunas: $tanggalLunas, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    jenis,
    nama,
    jumlahSen,
    kodeMataUang,
    kategoriId,
    jatuhTempo,
    frekuensi,
    kustomHariN,
    pengingatLeadHari,
    pengingatJam,
    kanalPengingat,
    prioritas,
    catatan,
    tautanBayar,
    statusAktif,
    lunas,
    tanggalLunas,
    dibuatPada,
    diubahPada,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagihanData &&
          other.id == this.id &&
          other.jenis == this.jenis &&
          other.nama == this.nama &&
          other.jumlahSen == this.jumlahSen &&
          other.kodeMataUang == this.kodeMataUang &&
          other.kategoriId == this.kategoriId &&
          other.jatuhTempo == this.jatuhTempo &&
          other.frekuensi == this.frekuensi &&
          other.kustomHariN == this.kustomHariN &&
          other.pengingatLeadHari == this.pengingatLeadHari &&
          other.pengingatJam == this.pengingatJam &&
          other.kanalPengingat == this.kanalPengingat &&
          other.prioritas == this.prioritas &&
          other.catatan == this.catatan &&
          other.tautanBayar == this.tautanBayar &&
          other.statusAktif == this.statusAktif &&
          other.lunas == this.lunas &&
          other.tanggalLunas == this.tanggalLunas &&
          other.dibuatPada == this.dibuatPada &&
          other.diubahPada == this.diubahPada);
}

class TagihanCompanion extends UpdateCompanion<TagihanData> {
  final Value<int> id;
  final Value<String> jenis;
  final Value<String> nama;
  final Value<int?> jumlahSen;
  final Value<String> kodeMataUang;
  final Value<int?> kategoriId;
  final Value<DateTime> jatuhTempo;
  final Value<String> frekuensi;
  final Value<int?> kustomHariN;
  final Value<String> pengingatLeadHari;
  final Value<String> pengingatJam;
  final Value<String> kanalPengingat;
  final Value<String> prioritas;
  final Value<String?> catatan;
  final Value<String?> tautanBayar;
  final Value<bool> statusAktif;
  final Value<bool> lunas;
  final Value<DateTime?> tanggalLunas;
  final Value<DateTime> dibuatPada;
  final Value<DateTime> diubahPada;
  const TagihanCompanion({
    this.id = const Value.absent(),
    this.jenis = const Value.absent(),
    this.nama = const Value.absent(),
    this.jumlahSen = const Value.absent(),
    this.kodeMataUang = const Value.absent(),
    this.kategoriId = const Value.absent(),
    this.jatuhTempo = const Value.absent(),
    this.frekuensi = const Value.absent(),
    this.kustomHariN = const Value.absent(),
    this.pengingatLeadHari = const Value.absent(),
    this.pengingatJam = const Value.absent(),
    this.kanalPengingat = const Value.absent(),
    this.prioritas = const Value.absent(),
    this.catatan = const Value.absent(),
    this.tautanBayar = const Value.absent(),
    this.statusAktif = const Value.absent(),
    this.lunas = const Value.absent(),
    this.tanggalLunas = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  });
  TagihanCompanion.insert({
    this.id = const Value.absent(),
    this.jenis = const Value.absent(),
    required String nama,
    this.jumlahSen = const Value.absent(),
    this.kodeMataUang = const Value.absent(),
    this.kategoriId = const Value.absent(),
    required DateTime jatuhTempo,
    this.frekuensi = const Value.absent(),
    this.kustomHariN = const Value.absent(),
    this.pengingatLeadHari = const Value.absent(),
    this.pengingatJam = const Value.absent(),
    this.kanalPengingat = const Value.absent(),
    this.prioritas = const Value.absent(),
    this.catatan = const Value.absent(),
    this.tautanBayar = const Value.absent(),
    this.statusAktif = const Value.absent(),
    this.lunas = const Value.absent(),
    this.tanggalLunas = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  }) : nama = Value(nama),
       jatuhTempo = Value(jatuhTempo);
  static Insertable<TagihanData> custom({
    Expression<int>? id,
    Expression<String>? jenis,
    Expression<String>? nama,
    Expression<int>? jumlahSen,
    Expression<String>? kodeMataUang,
    Expression<int>? kategoriId,
    Expression<DateTime>? jatuhTempo,
    Expression<String>? frekuensi,
    Expression<int>? kustomHariN,
    Expression<String>? pengingatLeadHari,
    Expression<String>? pengingatJam,
    Expression<String>? kanalPengingat,
    Expression<String>? prioritas,
    Expression<String>? catatan,
    Expression<String>? tautanBayar,
    Expression<bool>? statusAktif,
    Expression<bool>? lunas,
    Expression<DateTime>? tanggalLunas,
    Expression<DateTime>? dibuatPada,
    Expression<DateTime>? diubahPada,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jenis != null) 'jenis': jenis,
      if (nama != null) 'nama': nama,
      if (jumlahSen != null) 'jumlah_sen': jumlahSen,
      if (kodeMataUang != null) 'kode_mata_uang': kodeMataUang,
      if (kategoriId != null) 'kategori_id': kategoriId,
      if (jatuhTempo != null) 'jatuh_tempo': jatuhTempo,
      if (frekuensi != null) 'frekuensi': frekuensi,
      if (kustomHariN != null) 'kustom_hari_n': kustomHariN,
      if (pengingatLeadHari != null) 'pengingat_lead_hari': pengingatLeadHari,
      if (pengingatJam != null) 'pengingat_jam': pengingatJam,
      if (kanalPengingat != null) 'kanal_pengingat': kanalPengingat,
      if (prioritas != null) 'prioritas': prioritas,
      if (catatan != null) 'catatan': catatan,
      if (tautanBayar != null) 'tautan_bayar': tautanBayar,
      if (statusAktif != null) 'status_aktif': statusAktif,
      if (lunas != null) 'lunas': lunas,
      if (tanggalLunas != null) 'tanggal_lunas': tanggalLunas,
      if (dibuatPada != null) 'dibuat_pada': dibuatPada,
      if (diubahPada != null) 'diubah_pada': diubahPada,
    });
  }

  TagihanCompanion copyWith({
    Value<int>? id,
    Value<String>? jenis,
    Value<String>? nama,
    Value<int?>? jumlahSen,
    Value<String>? kodeMataUang,
    Value<int?>? kategoriId,
    Value<DateTime>? jatuhTempo,
    Value<String>? frekuensi,
    Value<int?>? kustomHariN,
    Value<String>? pengingatLeadHari,
    Value<String>? pengingatJam,
    Value<String>? kanalPengingat,
    Value<String>? prioritas,
    Value<String?>? catatan,
    Value<String?>? tautanBayar,
    Value<bool>? statusAktif,
    Value<bool>? lunas,
    Value<DateTime?>? tanggalLunas,
    Value<DateTime>? dibuatPada,
    Value<DateTime>? diubahPada,
  }) {
    return TagihanCompanion(
      id: id ?? this.id,
      jenis: jenis ?? this.jenis,
      nama: nama ?? this.nama,
      jumlahSen: jumlahSen ?? this.jumlahSen,
      kodeMataUang: kodeMataUang ?? this.kodeMataUang,
      kategoriId: kategoriId ?? this.kategoriId,
      jatuhTempo: jatuhTempo ?? this.jatuhTempo,
      frekuensi: frekuensi ?? this.frekuensi,
      kustomHariN: kustomHariN ?? this.kustomHariN,
      pengingatLeadHari: pengingatLeadHari ?? this.pengingatLeadHari,
      pengingatJam: pengingatJam ?? this.pengingatJam,
      kanalPengingat: kanalPengingat ?? this.kanalPengingat,
      prioritas: prioritas ?? this.prioritas,
      catatan: catatan ?? this.catatan,
      tautanBayar: tautanBayar ?? this.tautanBayar,
      statusAktif: statusAktif ?? this.statusAktif,
      lunas: lunas ?? this.lunas,
      tanggalLunas: tanggalLunas ?? this.tanggalLunas,
      dibuatPada: dibuatPada ?? this.dibuatPada,
      diubahPada: diubahPada ?? this.diubahPada,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (jenis.present) {
      map['jenis'] = Variable<String>(jenis.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (jumlahSen.present) {
      map['jumlah_sen'] = Variable<int>(jumlahSen.value);
    }
    if (kodeMataUang.present) {
      map['kode_mata_uang'] = Variable<String>(kodeMataUang.value);
    }
    if (kategoriId.present) {
      map['kategori_id'] = Variable<int>(kategoriId.value);
    }
    if (jatuhTempo.present) {
      map['jatuh_tempo'] = Variable<DateTime>(jatuhTempo.value);
    }
    if (frekuensi.present) {
      map['frekuensi'] = Variable<String>(frekuensi.value);
    }
    if (kustomHariN.present) {
      map['kustom_hari_n'] = Variable<int>(kustomHariN.value);
    }
    if (pengingatLeadHari.present) {
      map['pengingat_lead_hari'] = Variable<String>(pengingatLeadHari.value);
    }
    if (pengingatJam.present) {
      map['pengingat_jam'] = Variable<String>(pengingatJam.value);
    }
    if (kanalPengingat.present) {
      map['kanal_pengingat'] = Variable<String>(kanalPengingat.value);
    }
    if (prioritas.present) {
      map['prioritas'] = Variable<String>(prioritas.value);
    }
    if (catatan.present) {
      map['catatan'] = Variable<String>(catatan.value);
    }
    if (tautanBayar.present) {
      map['tautan_bayar'] = Variable<String>(tautanBayar.value);
    }
    if (statusAktif.present) {
      map['status_aktif'] = Variable<bool>(statusAktif.value);
    }
    if (lunas.present) {
      map['lunas'] = Variable<bool>(lunas.value);
    }
    if (tanggalLunas.present) {
      map['tanggal_lunas'] = Variable<DateTime>(tanggalLunas.value);
    }
    if (dibuatPada.present) {
      map['dibuat_pada'] = Variable<DateTime>(dibuatPada.value);
    }
    if (diubahPada.present) {
      map['diubah_pada'] = Variable<DateTime>(diubahPada.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagihanCompanion(')
          ..write('id: $id, ')
          ..write('jenis: $jenis, ')
          ..write('nama: $nama, ')
          ..write('jumlahSen: $jumlahSen, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('kategoriId: $kategoriId, ')
          ..write('jatuhTempo: $jatuhTempo, ')
          ..write('frekuensi: $frekuensi, ')
          ..write('kustomHariN: $kustomHariN, ')
          ..write('pengingatLeadHari: $pengingatLeadHari, ')
          ..write('pengingatJam: $pengingatJam, ')
          ..write('kanalPengingat: $kanalPengingat, ')
          ..write('prioritas: $prioritas, ')
          ..write('catatan: $catatan, ')
          ..write('tautanBayar: $tautanBayar, ')
          ..write('statusAktif: $statusAktif, ')
          ..write('lunas: $lunas, ')
          ..write('tanggalLunas: $tanggalLunas, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }
}

class $RiwayatPembayaranTable extends RiwayatPembayaran
    with TableInfo<$RiwayatPembayaranTable, RiwayatPembayaranData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RiwayatPembayaranTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tagihanIdMeta = const VerificationMeta(
    'tagihanId',
  );
  @override
  late final GeneratedColumn<int> tagihanId = GeneratedColumn<int>(
    'tagihan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tagihan (id)',
    ),
  );
  static const VerificationMeta _periodeJatuhTempoMeta = const VerificationMeta(
    'periodeJatuhTempo',
  );
  @override
  late final GeneratedColumn<DateTime> periodeJatuhTempo =
      GeneratedColumn<DateTime>(
        'periode_jatuh_tempo',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _jumlahSenMeta = const VerificationMeta(
    'jumlahSen',
  );
  @override
  late final GeneratedColumn<int> jumlahSen = GeneratedColumn<int>(
    'jumlah_sen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kodeMataUangMeta = const VerificationMeta(
    'kodeMataUang',
  );
  @override
  late final GeneratedColumn<String> kodeMataUang = GeneratedColumn<String>(
    'kode_mata_uang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('IDR'),
  );
  static const VerificationMeta _tanggalBayarMeta = const VerificationMeta(
    'tanggalBayar',
  );
  @override
  late final GeneratedColumn<DateTime> tanggalBayar = GeneratedColumn<DateTime>(
    'tanggal_bayar',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _telatHariMeta = const VerificationMeta(
    'telatHari',
  );
  @override
  late final GeneratedColumn<int> telatHari = GeneratedColumn<int>(
    'telat_hari',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viaMeta = const VerificationMeta('via');
  @override
  late final GeneratedColumn<String> via = GeneratedColumn<String>(
    'via',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tagihanId,
    periodeJatuhTempo,
    jumlahSen,
    kodeMataUang,
    tanggalBayar,
    telatHari,
    via,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'riwayat_pembayaran';
  @override
  VerificationContext validateIntegrity(
    Insertable<RiwayatPembayaranData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tagihan_id')) {
      context.handle(
        _tagihanIdMeta,
        tagihanId.isAcceptableOrUnknown(data['tagihan_id']!, _tagihanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagihanIdMeta);
    }
    if (data.containsKey('periode_jatuh_tempo')) {
      context.handle(
        _periodeJatuhTempoMeta,
        periodeJatuhTempo.isAcceptableOrUnknown(
          data['periode_jatuh_tempo']!,
          _periodeJatuhTempoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_periodeJatuhTempoMeta);
    }
    if (data.containsKey('jumlah_sen')) {
      context.handle(
        _jumlahSenMeta,
        jumlahSen.isAcceptableOrUnknown(data['jumlah_sen']!, _jumlahSenMeta),
      );
    } else if (isInserting) {
      context.missing(_jumlahSenMeta);
    }
    if (data.containsKey('kode_mata_uang')) {
      context.handle(
        _kodeMataUangMeta,
        kodeMataUang.isAcceptableOrUnknown(
          data['kode_mata_uang']!,
          _kodeMataUangMeta,
        ),
      );
    }
    if (data.containsKey('tanggal_bayar')) {
      context.handle(
        _tanggalBayarMeta,
        tanggalBayar.isAcceptableOrUnknown(
          data['tanggal_bayar']!,
          _tanggalBayarMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tanggalBayarMeta);
    }
    if (data.containsKey('telat_hari')) {
      context.handle(
        _telatHariMeta,
        telatHari.isAcceptableOrUnknown(data['telat_hari']!, _telatHariMeta),
      );
    }
    if (data.containsKey('via')) {
      context.handle(
        _viaMeta,
        via.isAcceptableOrUnknown(data['via']!, _viaMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RiwayatPembayaranData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RiwayatPembayaranData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tagihanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tagihan_id'],
      )!,
      periodeJatuhTempo: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}periode_jatuh_tempo'],
      )!,
      jumlahSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}jumlah_sen'],
      )!,
      kodeMataUang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kode_mata_uang'],
      )!,
      tanggalBayar: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tanggal_bayar'],
      )!,
      telatHari: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}telat_hari'],
      ),
      via: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}via'],
      )!,
    );
  }

  @override
  $RiwayatPembayaranTable createAlias(String alias) {
    return $RiwayatPembayaranTable(attachedDatabase, alias);
  }
}

class RiwayatPembayaranData extends DataClass
    implements Insertable<RiwayatPembayaranData> {
  final int id;
  final int tagihanId;

  /// Periode jatuh tempo yang dibayar.
  final DateTime periodeJatuhTempo;
  final int jumlahSen;
  final String kodeMataUang;
  final DateTime tanggalBayar;
  final int? telatHari;
  final String via;
  const RiwayatPembayaranData({
    required this.id,
    required this.tagihanId,
    required this.periodeJatuhTempo,
    required this.jumlahSen,
    required this.kodeMataUang,
    required this.tanggalBayar,
    this.telatHari,
    required this.via,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tagihan_id'] = Variable<int>(tagihanId);
    map['periode_jatuh_tempo'] = Variable<DateTime>(periodeJatuhTempo);
    map['jumlah_sen'] = Variable<int>(jumlahSen);
    map['kode_mata_uang'] = Variable<String>(kodeMataUang);
    map['tanggal_bayar'] = Variable<DateTime>(tanggalBayar);
    if (!nullToAbsent || telatHari != null) {
      map['telat_hari'] = Variable<int>(telatHari);
    }
    map['via'] = Variable<String>(via);
    return map;
  }

  RiwayatPembayaranCompanion toCompanion(bool nullToAbsent) {
    return RiwayatPembayaranCompanion(
      id: Value(id),
      tagihanId: Value(tagihanId),
      periodeJatuhTempo: Value(periodeJatuhTempo),
      jumlahSen: Value(jumlahSen),
      kodeMataUang: Value(kodeMataUang),
      tanggalBayar: Value(tanggalBayar),
      telatHari: telatHari == null && nullToAbsent
          ? const Value.absent()
          : Value(telatHari),
      via: Value(via),
    );
  }

  factory RiwayatPembayaranData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RiwayatPembayaranData(
      id: serializer.fromJson<int>(json['id']),
      tagihanId: serializer.fromJson<int>(json['tagihanId']),
      periodeJatuhTempo: serializer.fromJson<DateTime>(
        json['periodeJatuhTempo'],
      ),
      jumlahSen: serializer.fromJson<int>(json['jumlahSen']),
      kodeMataUang: serializer.fromJson<String>(json['kodeMataUang']),
      tanggalBayar: serializer.fromJson<DateTime>(json['tanggalBayar']),
      telatHari: serializer.fromJson<int?>(json['telatHari']),
      via: serializer.fromJson<String>(json['via']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tagihanId': serializer.toJson<int>(tagihanId),
      'periodeJatuhTempo': serializer.toJson<DateTime>(periodeJatuhTempo),
      'jumlahSen': serializer.toJson<int>(jumlahSen),
      'kodeMataUang': serializer.toJson<String>(kodeMataUang),
      'tanggalBayar': serializer.toJson<DateTime>(tanggalBayar),
      'telatHari': serializer.toJson<int?>(telatHari),
      'via': serializer.toJson<String>(via),
    };
  }

  RiwayatPembayaranData copyWith({
    int? id,
    int? tagihanId,
    DateTime? periodeJatuhTempo,
    int? jumlahSen,
    String? kodeMataUang,
    DateTime? tanggalBayar,
    Value<int?> telatHari = const Value.absent(),
    String? via,
  }) => RiwayatPembayaranData(
    id: id ?? this.id,
    tagihanId: tagihanId ?? this.tagihanId,
    periodeJatuhTempo: periodeJatuhTempo ?? this.periodeJatuhTempo,
    jumlahSen: jumlahSen ?? this.jumlahSen,
    kodeMataUang: kodeMataUang ?? this.kodeMataUang,
    tanggalBayar: tanggalBayar ?? this.tanggalBayar,
    telatHari: telatHari.present ? telatHari.value : this.telatHari,
    via: via ?? this.via,
  );
  RiwayatPembayaranData copyWithCompanion(RiwayatPembayaranCompanion data) {
    return RiwayatPembayaranData(
      id: data.id.present ? data.id.value : this.id,
      tagihanId: data.tagihanId.present ? data.tagihanId.value : this.tagihanId,
      periodeJatuhTempo: data.periodeJatuhTempo.present
          ? data.periodeJatuhTempo.value
          : this.periodeJatuhTempo,
      jumlahSen: data.jumlahSen.present ? data.jumlahSen.value : this.jumlahSen,
      kodeMataUang: data.kodeMataUang.present
          ? data.kodeMataUang.value
          : this.kodeMataUang,
      tanggalBayar: data.tanggalBayar.present
          ? data.tanggalBayar.value
          : this.tanggalBayar,
      telatHari: data.telatHari.present ? data.telatHari.value : this.telatHari,
      via: data.via.present ? data.via.value : this.via,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RiwayatPembayaranData(')
          ..write('id: $id, ')
          ..write('tagihanId: $tagihanId, ')
          ..write('periodeJatuhTempo: $periodeJatuhTempo, ')
          ..write('jumlahSen: $jumlahSen, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('tanggalBayar: $tanggalBayar, ')
          ..write('telatHari: $telatHari, ')
          ..write('via: $via')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tagihanId,
    periodeJatuhTempo,
    jumlahSen,
    kodeMataUang,
    tanggalBayar,
    telatHari,
    via,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RiwayatPembayaranData &&
          other.id == this.id &&
          other.tagihanId == this.tagihanId &&
          other.periodeJatuhTempo == this.periodeJatuhTempo &&
          other.jumlahSen == this.jumlahSen &&
          other.kodeMataUang == this.kodeMataUang &&
          other.tanggalBayar == this.tanggalBayar &&
          other.telatHari == this.telatHari &&
          other.via == this.via);
}

class RiwayatPembayaranCompanion
    extends UpdateCompanion<RiwayatPembayaranData> {
  final Value<int> id;
  final Value<int> tagihanId;
  final Value<DateTime> periodeJatuhTempo;
  final Value<int> jumlahSen;
  final Value<String> kodeMataUang;
  final Value<DateTime> tanggalBayar;
  final Value<int?> telatHari;
  final Value<String> via;
  const RiwayatPembayaranCompanion({
    this.id = const Value.absent(),
    this.tagihanId = const Value.absent(),
    this.periodeJatuhTempo = const Value.absent(),
    this.jumlahSen = const Value.absent(),
    this.kodeMataUang = const Value.absent(),
    this.tanggalBayar = const Value.absent(),
    this.telatHari = const Value.absent(),
    this.via = const Value.absent(),
  });
  RiwayatPembayaranCompanion.insert({
    this.id = const Value.absent(),
    required int tagihanId,
    required DateTime periodeJatuhTempo,
    required int jumlahSen,
    this.kodeMataUang = const Value.absent(),
    required DateTime tanggalBayar,
    this.telatHari = const Value.absent(),
    this.via = const Value.absent(),
  }) : tagihanId = Value(tagihanId),
       periodeJatuhTempo = Value(periodeJatuhTempo),
       jumlahSen = Value(jumlahSen),
       tanggalBayar = Value(tanggalBayar);
  static Insertable<RiwayatPembayaranData> custom({
    Expression<int>? id,
    Expression<int>? tagihanId,
    Expression<DateTime>? periodeJatuhTempo,
    Expression<int>? jumlahSen,
    Expression<String>? kodeMataUang,
    Expression<DateTime>? tanggalBayar,
    Expression<int>? telatHari,
    Expression<String>? via,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tagihanId != null) 'tagihan_id': tagihanId,
      if (periodeJatuhTempo != null) 'periode_jatuh_tempo': periodeJatuhTempo,
      if (jumlahSen != null) 'jumlah_sen': jumlahSen,
      if (kodeMataUang != null) 'kode_mata_uang': kodeMataUang,
      if (tanggalBayar != null) 'tanggal_bayar': tanggalBayar,
      if (telatHari != null) 'telat_hari': telatHari,
      if (via != null) 'via': via,
    });
  }

  RiwayatPembayaranCompanion copyWith({
    Value<int>? id,
    Value<int>? tagihanId,
    Value<DateTime>? periodeJatuhTempo,
    Value<int>? jumlahSen,
    Value<String>? kodeMataUang,
    Value<DateTime>? tanggalBayar,
    Value<int?>? telatHari,
    Value<String>? via,
  }) {
    return RiwayatPembayaranCompanion(
      id: id ?? this.id,
      tagihanId: tagihanId ?? this.tagihanId,
      periodeJatuhTempo: periodeJatuhTempo ?? this.periodeJatuhTempo,
      jumlahSen: jumlahSen ?? this.jumlahSen,
      kodeMataUang: kodeMataUang ?? this.kodeMataUang,
      tanggalBayar: tanggalBayar ?? this.tanggalBayar,
      telatHari: telatHari ?? this.telatHari,
      via: via ?? this.via,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tagihanId.present) {
      map['tagihan_id'] = Variable<int>(tagihanId.value);
    }
    if (periodeJatuhTempo.present) {
      map['periode_jatuh_tempo'] = Variable<DateTime>(periodeJatuhTempo.value);
    }
    if (jumlahSen.present) {
      map['jumlah_sen'] = Variable<int>(jumlahSen.value);
    }
    if (kodeMataUang.present) {
      map['kode_mata_uang'] = Variable<String>(kodeMataUang.value);
    }
    if (tanggalBayar.present) {
      map['tanggal_bayar'] = Variable<DateTime>(tanggalBayar.value);
    }
    if (telatHari.present) {
      map['telat_hari'] = Variable<int>(telatHari.value);
    }
    if (via.present) {
      map['via'] = Variable<String>(via.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RiwayatPembayaranCompanion(')
          ..write('id: $id, ')
          ..write('tagihanId: $tagihanId, ')
          ..write('periodeJatuhTempo: $periodeJatuhTempo, ')
          ..write('jumlahSen: $jumlahSen, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('tanggalBayar: $tanggalBayar, ')
          ..write('telatHari: $telatHari, ')
          ..write('via: $via')
          ..write(')'))
        .toString();
  }
}

class $PemasukanBulananTable extends PemasukanBulanan
    with TableInfo<$PemasukanBulananTable, PemasukanBulananData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PemasukanBulananTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bulanMeta = const VerificationMeta('bulan');
  @override
  late final GeneratedColumn<String> bulan = GeneratedColumn<String>(
    'bulan',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jumlahSenMeta = const VerificationMeta(
    'jumlahSen',
  );
  @override
  late final GeneratedColumn<int> jumlahSen = GeneratedColumn<int>(
    'jumlah_sen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sumberMeta = const VerificationMeta('sumber');
  @override
  late final GeneratedColumn<String> sumber = GeneratedColumn<String>(
    'sumber',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Gaji'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, bulan, jumlahSen, sumber];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pemasukan_bulanan';
  @override
  VerificationContext validateIntegrity(
    Insertable<PemasukanBulananData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bulan')) {
      context.handle(
        _bulanMeta,
        bulan.isAcceptableOrUnknown(data['bulan']!, _bulanMeta),
      );
    } else if (isInserting) {
      context.missing(_bulanMeta);
    }
    if (data.containsKey('jumlah_sen')) {
      context.handle(
        _jumlahSenMeta,
        jumlahSen.isAcceptableOrUnknown(data['jumlah_sen']!, _jumlahSenMeta),
      );
    }
    if (data.containsKey('sumber')) {
      context.handle(
        _sumberMeta,
        sumber.isAcceptableOrUnknown(data['sumber']!, _sumberMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PemasukanBulananData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PemasukanBulananData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bulan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bulan'],
      )!,
      jumlahSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}jumlah_sen'],
      )!,
      sumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sumber'],
      )!,
    );
  }

  @override
  $PemasukanBulananTable createAlias(String alias) {
    return $PemasukanBulananTable(attachedDatabase, alias);
  }
}

class PemasukanBulananData extends DataClass
    implements Insertable<PemasukanBulananData> {
  final int id;

  /// Bulan "YYYY-MM" (satu baris per bulan, mudah di-query).
  final String bulan;
  final int jumlahSen;
  final String sumber;
  const PemasukanBulananData({
    required this.id,
    required this.bulan,
    required this.jumlahSen,
    required this.sumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bulan'] = Variable<String>(bulan);
    map['jumlah_sen'] = Variable<int>(jumlahSen);
    map['sumber'] = Variable<String>(sumber);
    return map;
  }

  PemasukanBulananCompanion toCompanion(bool nullToAbsent) {
    return PemasukanBulananCompanion(
      id: Value(id),
      bulan: Value(bulan),
      jumlahSen: Value(jumlahSen),
      sumber: Value(sumber),
    );
  }

  factory PemasukanBulananData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PemasukanBulananData(
      id: serializer.fromJson<int>(json['id']),
      bulan: serializer.fromJson<String>(json['bulan']),
      jumlahSen: serializer.fromJson<int>(json['jumlahSen']),
      sumber: serializer.fromJson<String>(json['sumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bulan': serializer.toJson<String>(bulan),
      'jumlahSen': serializer.toJson<int>(jumlahSen),
      'sumber': serializer.toJson<String>(sumber),
    };
  }

  PemasukanBulananData copyWith({
    int? id,
    String? bulan,
    int? jumlahSen,
    String? sumber,
  }) => PemasukanBulananData(
    id: id ?? this.id,
    bulan: bulan ?? this.bulan,
    jumlahSen: jumlahSen ?? this.jumlahSen,
    sumber: sumber ?? this.sumber,
  );
  PemasukanBulananData copyWithCompanion(PemasukanBulananCompanion data) {
    return PemasukanBulananData(
      id: data.id.present ? data.id.value : this.id,
      bulan: data.bulan.present ? data.bulan.value : this.bulan,
      jumlahSen: data.jumlahSen.present ? data.jumlahSen.value : this.jumlahSen,
      sumber: data.sumber.present ? data.sumber.value : this.sumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PemasukanBulananData(')
          ..write('id: $id, ')
          ..write('bulan: $bulan, ')
          ..write('jumlahSen: $jumlahSen, ')
          ..write('sumber: $sumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bulan, jumlahSen, sumber);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PemasukanBulananData &&
          other.id == this.id &&
          other.bulan == this.bulan &&
          other.jumlahSen == this.jumlahSen &&
          other.sumber == this.sumber);
}

class PemasukanBulananCompanion extends UpdateCompanion<PemasukanBulananData> {
  final Value<int> id;
  final Value<String> bulan;
  final Value<int> jumlahSen;
  final Value<String> sumber;
  const PemasukanBulananCompanion({
    this.id = const Value.absent(),
    this.bulan = const Value.absent(),
    this.jumlahSen = const Value.absent(),
    this.sumber = const Value.absent(),
  });
  PemasukanBulananCompanion.insert({
    this.id = const Value.absent(),
    required String bulan,
    this.jumlahSen = const Value.absent(),
    this.sumber = const Value.absent(),
  }) : bulan = Value(bulan);
  static Insertable<PemasukanBulananData> custom({
    Expression<int>? id,
    Expression<String>? bulan,
    Expression<int>? jumlahSen,
    Expression<String>? sumber,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bulan != null) 'bulan': bulan,
      if (jumlahSen != null) 'jumlah_sen': jumlahSen,
      if (sumber != null) 'sumber': sumber,
    });
  }

  PemasukanBulananCompanion copyWith({
    Value<int>? id,
    Value<String>? bulan,
    Value<int>? jumlahSen,
    Value<String>? sumber,
  }) {
    return PemasukanBulananCompanion(
      id: id ?? this.id,
      bulan: bulan ?? this.bulan,
      jumlahSen: jumlahSen ?? this.jumlahSen,
      sumber: sumber ?? this.sumber,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bulan.present) {
      map['bulan'] = Variable<String>(bulan.value);
    }
    if (jumlahSen.present) {
      map['jumlah_sen'] = Variable<int>(jumlahSen.value);
    }
    if (sumber.present) {
      map['sumber'] = Variable<String>(sumber.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PemasukanBulananCompanion(')
          ..write('id: $id, ')
          ..write('bulan: $bulan, ')
          ..write('jumlahSen: $jumlahSen, ')
          ..write('sumber: $sumber')
          ..write(')'))
        .toString();
  }
}

class $PengaturanTable extends Pengaturan
    with TableInfo<$PengaturanTable, PengaturanData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PengaturanTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kunciMeta = const VerificationMeta('kunci');
  @override
  late final GeneratedColumn<String> kunci = GeneratedColumn<String>(
    'kunci',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nilaiMeta = const VerificationMeta('nilai');
  @override
  late final GeneratedColumn<String> nilai = GeneratedColumn<String>(
    'nilai',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [kunci, nilai];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pengaturan';
  @override
  VerificationContext validateIntegrity(
    Insertable<PengaturanData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kunci')) {
      context.handle(
        _kunciMeta,
        kunci.isAcceptableOrUnknown(data['kunci']!, _kunciMeta),
      );
    } else if (isInserting) {
      context.missing(_kunciMeta);
    }
    if (data.containsKey('nilai')) {
      context.handle(
        _nilaiMeta,
        nilai.isAcceptableOrUnknown(data['nilai']!, _nilaiMeta),
      );
    } else if (isInserting) {
      context.missing(_nilaiMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kunci};
  @override
  PengaturanData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PengaturanData(
      kunci: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kunci'],
      )!,
      nilai: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nilai'],
      )!,
    );
  }

  @override
  $PengaturanTable createAlias(String alias) {
    return $PengaturanTable(attachedDatabase, alias);
  }
}

class PengaturanData extends DataClass implements Insertable<PengaturanData> {
  final String kunci;
  final String nilai;
  const PengaturanData({required this.kunci, required this.nilai});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kunci'] = Variable<String>(kunci);
    map['nilai'] = Variable<String>(nilai);
    return map;
  }

  PengaturanCompanion toCompanion(bool nullToAbsent) {
    return PengaturanCompanion(kunci: Value(kunci), nilai: Value(nilai));
  }

  factory PengaturanData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PengaturanData(
      kunci: serializer.fromJson<String>(json['kunci']),
      nilai: serializer.fromJson<String>(json['nilai']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kunci': serializer.toJson<String>(kunci),
      'nilai': serializer.toJson<String>(nilai),
    };
  }

  PengaturanData copyWith({String? kunci, String? nilai}) =>
      PengaturanData(kunci: kunci ?? this.kunci, nilai: nilai ?? this.nilai);
  PengaturanData copyWithCompanion(PengaturanCompanion data) {
    return PengaturanData(
      kunci: data.kunci.present ? data.kunci.value : this.kunci,
      nilai: data.nilai.present ? data.nilai.value : this.nilai,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PengaturanData(')
          ..write('kunci: $kunci, ')
          ..write('nilai: $nilai')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kunci, nilai);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PengaturanData &&
          other.kunci == this.kunci &&
          other.nilai == this.nilai);
}

class PengaturanCompanion extends UpdateCompanion<PengaturanData> {
  final Value<String> kunci;
  final Value<String> nilai;
  final Value<int> rowid;
  const PengaturanCompanion({
    this.kunci = const Value.absent(),
    this.nilai = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PengaturanCompanion.insert({
    required String kunci,
    required String nilai,
    this.rowid = const Value.absent(),
  }) : kunci = Value(kunci),
       nilai = Value(nilai);
  static Insertable<PengaturanData> custom({
    Expression<String>? kunci,
    Expression<String>? nilai,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kunci != null) 'kunci': kunci,
      if (nilai != null) 'nilai': nilai,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PengaturanCompanion copyWith({
    Value<String>? kunci,
    Value<String>? nilai,
    Value<int>? rowid,
  }) {
    return PengaturanCompanion(
      kunci: kunci ?? this.kunci,
      nilai: nilai ?? this.nilai,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kunci.present) {
      map['kunci'] = Variable<String>(kunci.value);
    }
    if (nilai.present) {
      map['nilai'] = Variable<String>(nilai.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PengaturanCompanion(')
          ..write('kunci: $kunci, ')
          ..write('nilai: $nilai, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $KategoriTable kategori = $KategoriTable(this);
  late final $TagihanTable tagihan = $TagihanTable(this);
  late final $RiwayatPembayaranTable riwayatPembayaran =
      $RiwayatPembayaranTable(this);
  late final $PemasukanBulananTable pemasukanBulanan = $PemasukanBulananTable(
    this,
  );
  late final $PengaturanTable pengaturan = $PengaturanTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    kategori,
    tagihan,
    riwayatPembayaran,
    pemasukanBulanan,
    pengaturan,
  ];
}

typedef $$KategoriTableCreateCompanionBuilder = KategoriCompanion Function({
  Value<int> id,
  required String nama,
  Value<String> ikon,
  Value<String> warna,
  Value<int> urutan,
});
typedef $$KategoriTableUpdateCompanionBuilder = KategoriCompanion Function({
  Value<int> id,
  Value<String> nama,
  Value<String> ikon,
  Value<String> warna,
  Value<int> urutan,
});

final class $$KategoriTableReferences
    extends BaseReferences<_$AppDatabase, $KategoriTable, KategoriData> {
  $$KategoriTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TagihanTable, List<TagihanData>>
  _tagihanRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tagihan,
    aliasName: 'kategori__id__tagihan__kategori_id',
  );

  $$TagihanTableProcessedTableManager get tagihanRefs {
    final manager = $$TagihanTableTableManager(
      $_db,
      $_db.tagihan,
    ).filter((f) => f.kategoriId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tagihanRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$KategoriTableFilterComposer
    extends Composer<_$AppDatabase, $KategoriTable> {
  $$KategoriTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ikon => $composableBuilder(
    column: $table.ikon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get warna => $composableBuilder(
    column: $table.warna,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get urutan => $composableBuilder(
    column: $table.urutan,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tagihanRefs(
    Expression<bool> Function($$TagihanTableFilterComposer f) f,
  ) {
    final $$TagihanTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tagihan,
      getReferencedColumn: (t) => t.kategoriId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagihanTableFilterComposer(
            $db: $db,
            $table: $db.tagihan,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KategoriTableOrderingComposer
    extends Composer<_$AppDatabase, $KategoriTable> {
  $$KategoriTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ikon => $composableBuilder(
    column: $table.ikon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get warna => $composableBuilder(
    column: $table.warna,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get urutan => $composableBuilder(
    column: $table.urutan,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KategoriTableAnnotationComposer
    extends Composer<_$AppDatabase, $KategoriTable> {
  $$KategoriTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<String> get ikon =>
      $composableBuilder(column: $table.ikon, builder: (column) => column);

  GeneratedColumn<String> get warna =>
      $composableBuilder(column: $table.warna, builder: (column) => column);

  GeneratedColumn<int> get urutan =>
      $composableBuilder(column: $table.urutan, builder: (column) => column);

  Expression<T> tagihanRefs<T extends Object>(
    Expression<T> Function($$TagihanTableAnnotationComposer a) f,
  ) {
    final $$TagihanTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tagihan,
      getReferencedColumn: (t) => t.kategoriId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagihanTableAnnotationComposer(
            $db: $db,
            $table: $db.tagihan,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KategoriTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KategoriTable,
          KategoriData,
          $$KategoriTableFilterComposer,
          $$KategoriTableOrderingComposer,
          $$KategoriTableAnnotationComposer,
          $$KategoriTableCreateCompanionBuilder,
          $$KategoriTableUpdateCompanionBuilder,
          (KategoriData, $$KategoriTableReferences),
          KategoriData,
          PrefetchHooks Function({bool tagihanRefs})
        > {
  $$KategoriTableTableManager(_$AppDatabase db, $KategoriTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KategoriTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KategoriTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KategoriTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<String> ikon = const Value.absent(),
                Value<String> warna = const Value.absent(),
                Value<int> urutan = const Value.absent(),
              }) => KategoriCompanion(
                id: id,
                nama: nama,
                ikon: ikon,
                warna: warna,
                urutan: urutan,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nama,
                Value<String> ikon = const Value.absent(),
                Value<String> warna = const Value.absent(),
                Value<int> urutan = const Value.absent(),
              }) => KategoriCompanion.insert(
                id: id,
                nama: nama,
                ikon: ikon,
                warna: warna,
                urutan: urutan,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KategoriTable, KategoriData>(table),
                  $$KategoriTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tagihanRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tagihanRefs) db.tagihan],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tagihanRefs)
                    await $_getPrefetchedData<
                      KategoriData,
                      $KategoriTable,
                      TagihanData
                    >(
                      currentTable: table,
                      referencedTable: $$KategoriTableReferences
                          ._tagihanRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$KategoriTableReferences(db, table, p0).tagihanRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.kategoriId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$KategoriTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KategoriTable,
      KategoriData,
      $$KategoriTableFilterComposer,
      $$KategoriTableOrderingComposer,
      $$KategoriTableAnnotationComposer,
      $$KategoriTableCreateCompanionBuilder,
      $$KategoriTableUpdateCompanionBuilder,
      (KategoriData, $$KategoriTableReferences),
      KategoriData,
      PrefetchHooks Function({bool tagihanRefs})
    >;
typedef $$TagihanTableCreateCompanionBuilder = TagihanCompanion Function({
  Value<int> id,
  Value<String> jenis,
  required String nama,
  Value<int?> jumlahSen,
  Value<String> kodeMataUang,
  Value<int?> kategoriId,
  required DateTime jatuhTempo,
  Value<String> frekuensi,
  Value<int?> kustomHariN,
  Value<String> pengingatLeadHari,
  Value<String> pengingatJam,
  Value<String> kanalPengingat,
  Value<String> prioritas,
  Value<String?> catatan,
  Value<String?> tautanBayar,
  Value<bool> statusAktif,
  Value<bool> lunas,
  Value<DateTime?> tanggalLunas,
  Value<DateTime> dibuatPada,
  Value<DateTime> diubahPada,
});
typedef $$TagihanTableUpdateCompanionBuilder = TagihanCompanion Function({
  Value<int> id,
  Value<String> jenis,
  Value<String> nama,
  Value<int?> jumlahSen,
  Value<String> kodeMataUang,
  Value<int?> kategoriId,
  Value<DateTime> jatuhTempo,
  Value<String> frekuensi,
  Value<int?> kustomHariN,
  Value<String> pengingatLeadHari,
  Value<String> pengingatJam,
  Value<String> kanalPengingat,
  Value<String> prioritas,
  Value<String?> catatan,
  Value<String?> tautanBayar,
  Value<bool> statusAktif,
  Value<bool> lunas,
  Value<DateTime?> tanggalLunas,
  Value<DateTime> dibuatPada,
  Value<DateTime> diubahPada,
});

final class $$TagihanTableReferences
    extends BaseReferences<_$AppDatabase, $TagihanTable, TagihanData> {
  $$TagihanTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $KategoriTable _kategoriIdTable(_$AppDatabase db) =>
      db.kategori.createAlias('tagihan__kategori_id__kategori__id');

  $$KategoriTableProcessedTableManager? get kategoriId {
    final $_column = $_itemColumn<int>('kategori_id');
    if ($_column == null) return null;
    final manager = $$KategoriTableTableManager(
      $_db,
      $_db.kategori,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_kategoriIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $RiwayatPembayaranTable,
    List<RiwayatPembayaranData>
  >
  _riwayatPembayaranRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.riwayatPembayaran,
        aliasName: 'tagihan__id__riwayat_pembayaran__tagihan_id',
      );

  $$RiwayatPembayaranTableProcessedTableManager get riwayatPembayaranRefs {
    final manager = $$RiwayatPembayaranTableTableManager(
      $_db,
      $_db.riwayatPembayaran,
    ).filter((f) => f.tagihanId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _riwayatPembayaranRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagihanTableFilterComposer
    extends Composer<_$AppDatabase, $TagihanTable> {
  $$TagihanTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jenis => $composableBuilder(
    column: $table.jenis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get jumlahSen => $composableBuilder(
    column: $table.jumlahSen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get jatuhTempo => $composableBuilder(
    column: $table.jatuhTempo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frekuensi => $composableBuilder(
    column: $table.frekuensi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kustomHariN => $composableBuilder(
    column: $table.kustomHariN,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pengingatLeadHari => $composableBuilder(
    column: $table.pengingatLeadHari,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pengingatJam => $composableBuilder(
    column: $table.pengingatJam,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kanalPengingat => $composableBuilder(
    column: $table.kanalPengingat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prioritas => $composableBuilder(
    column: $table.prioritas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catatan => $composableBuilder(
    column: $table.catatan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tautanBayar => $composableBuilder(
    column: $table.tautanBayar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get statusAktif => $composableBuilder(
    column: $table.statusAktif,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lunas => $composableBuilder(
    column: $table.lunas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tanggalLunas => $composableBuilder(
    column: $table.tanggalLunas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dibuatPada => $composableBuilder(
    column: $table.dibuatPada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get diubahPada => $composableBuilder(
    column: $table.diubahPada,
    builder: (column) => ColumnFilters(column),
  );

  $$KategoriTableFilterComposer get kategoriId {
    final $$KategoriTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kategoriId,
      referencedTable: $db.kategori,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KategoriTableFilterComposer(
            $db: $db,
            $table: $db.kategori,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> riwayatPembayaranRefs(
    Expression<bool> Function($$RiwayatPembayaranTableFilterComposer f) f,
  ) {
    final $$RiwayatPembayaranTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.riwayatPembayaran,
      getReferencedColumn: (t) => t.tagihanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RiwayatPembayaranTableFilterComposer(
            $db: $db,
            $table: $db.riwayatPembayaran,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagihanTableOrderingComposer
    extends Composer<_$AppDatabase, $TagihanTable> {
  $$TagihanTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jenis => $composableBuilder(
    column: $table.jenis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get jumlahSen => $composableBuilder(
    column: $table.jumlahSen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get jatuhTempo => $composableBuilder(
    column: $table.jatuhTempo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frekuensi => $composableBuilder(
    column: $table.frekuensi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kustomHariN => $composableBuilder(
    column: $table.kustomHariN,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pengingatLeadHari => $composableBuilder(
    column: $table.pengingatLeadHari,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pengingatJam => $composableBuilder(
    column: $table.pengingatJam,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kanalPengingat => $composableBuilder(
    column: $table.kanalPengingat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prioritas => $composableBuilder(
    column: $table.prioritas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catatan => $composableBuilder(
    column: $table.catatan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tautanBayar => $composableBuilder(
    column: $table.tautanBayar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get statusAktif => $composableBuilder(
    column: $table.statusAktif,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lunas => $composableBuilder(
    column: $table.lunas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tanggalLunas => $composableBuilder(
    column: $table.tanggalLunas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dibuatPada => $composableBuilder(
    column: $table.dibuatPada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get diubahPada => $composableBuilder(
    column: $table.diubahPada,
    builder: (column) => ColumnOrderings(column),
  );

  $$KategoriTableOrderingComposer get kategoriId {
    final $$KategoriTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kategoriId,
      referencedTable: $db.kategori,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KategoriTableOrderingComposer(
            $db: $db,
            $table: $db.kategori,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagihanTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagihanTable> {
  $$TagihanTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get jenis =>
      $composableBuilder(column: $table.jenis, builder: (column) => column);

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<int> get jumlahSen =>
      $composableBuilder(column: $table.jumlahSen, builder: (column) => column);

  GeneratedColumn<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get jatuhTempo => $composableBuilder(
    column: $table.jatuhTempo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frekuensi =>
      $composableBuilder(column: $table.frekuensi, builder: (column) => column);

  GeneratedColumn<int> get kustomHariN => $composableBuilder(
    column: $table.kustomHariN,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pengingatLeadHari => $composableBuilder(
    column: $table.pengingatLeadHari,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pengingatJam => $composableBuilder(
    column: $table.pengingatJam,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kanalPengingat => $composableBuilder(
    column: $table.kanalPengingat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prioritas =>
      $composableBuilder(column: $table.prioritas, builder: (column) => column);

  GeneratedColumn<String> get catatan =>
      $composableBuilder(column: $table.catatan, builder: (column) => column);

  GeneratedColumn<String> get tautanBayar => $composableBuilder(
    column: $table.tautanBayar,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get statusAktif => $composableBuilder(
    column: $table.statusAktif,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get lunas =>
      $composableBuilder(column: $table.lunas, builder: (column) => column);

  GeneratedColumn<DateTime> get tanggalLunas => $composableBuilder(
    column: $table.tanggalLunas,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dibuatPada => $composableBuilder(
    column: $table.dibuatPada,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get diubahPada => $composableBuilder(
    column: $table.diubahPada,
    builder: (column) => column,
  );

  $$KategoriTableAnnotationComposer get kategoriId {
    final $$KategoriTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kategoriId,
      referencedTable: $db.kategori,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KategoriTableAnnotationComposer(
            $db: $db,
            $table: $db.kategori,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> riwayatPembayaranRefs<T extends Object>(
    Expression<T> Function($$RiwayatPembayaranTableAnnotationComposer a) f,
  ) {
    final $$RiwayatPembayaranTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.riwayatPembayaran,
          getReferencedColumn: (t) => t.tagihanId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RiwayatPembayaranTableAnnotationComposer(
                $db: $db,
                $table: $db.riwayatPembayaran,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TagihanTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagihanTable,
          TagihanData,
          $$TagihanTableFilterComposer,
          $$TagihanTableOrderingComposer,
          $$TagihanTableAnnotationComposer,
          $$TagihanTableCreateCompanionBuilder,
          $$TagihanTableUpdateCompanionBuilder,
          (TagihanData, $$TagihanTableReferences),
          TagihanData,
          PrefetchHooks Function({bool kategoriId, bool riwayatPembayaranRefs})
        > {
  $$TagihanTableTableManager(_$AppDatabase db, $TagihanTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagihanTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagihanTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagihanTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> jenis = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<int?> jumlahSen = const Value.absent(),
                Value<String> kodeMataUang = const Value.absent(),
                Value<int?> kategoriId = const Value.absent(),
                Value<DateTime> jatuhTempo = const Value.absent(),
                Value<String> frekuensi = const Value.absent(),
                Value<int?> kustomHariN = const Value.absent(),
                Value<String> pengingatLeadHari = const Value.absent(),
                Value<String> pengingatJam = const Value.absent(),
                Value<String> kanalPengingat = const Value.absent(),
                Value<String> prioritas = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<String?> tautanBayar = const Value.absent(),
                Value<bool> statusAktif = const Value.absent(),
                Value<bool> lunas = const Value.absent(),
                Value<DateTime?> tanggalLunas = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => TagihanCompanion(
                id: id,
                jenis: jenis,
                nama: nama,
                jumlahSen: jumlahSen,
                kodeMataUang: kodeMataUang,
                kategoriId: kategoriId,
                jatuhTempo: jatuhTempo,
                frekuensi: frekuensi,
                kustomHariN: kustomHariN,
                pengingatLeadHari: pengingatLeadHari,
                pengingatJam: pengingatJam,
                kanalPengingat: kanalPengingat,
                prioritas: prioritas,
                catatan: catatan,
                tautanBayar: tautanBayar,
                statusAktif: statusAktif,
                lunas: lunas,
                tanggalLunas: tanggalLunas,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> jenis = const Value.absent(),
                required String nama,
                Value<int?> jumlahSen = const Value.absent(),
                Value<String> kodeMataUang = const Value.absent(),
                Value<int?> kategoriId = const Value.absent(),
                required DateTime jatuhTempo,
                Value<String> frekuensi = const Value.absent(),
                Value<int?> kustomHariN = const Value.absent(),
                Value<String> pengingatLeadHari = const Value.absent(),
                Value<String> pengingatJam = const Value.absent(),
                Value<String> kanalPengingat = const Value.absent(),
                Value<String> prioritas = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<String?> tautanBayar = const Value.absent(),
                Value<bool> statusAktif = const Value.absent(),
                Value<bool> lunas = const Value.absent(),
                Value<DateTime?> tanggalLunas = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => TagihanCompanion.insert(
                id: id,
                jenis: jenis,
                nama: nama,
                jumlahSen: jumlahSen,
                kodeMataUang: kodeMataUang,
                kategoriId: kategoriId,
                jatuhTempo: jatuhTempo,
                frekuensi: frekuensi,
                kustomHariN: kustomHariN,
                pengingatLeadHari: pengingatLeadHari,
                pengingatJam: pengingatJam,
                kanalPengingat: kanalPengingat,
                prioritas: prioritas,
                catatan: catatan,
                tautanBayar: tautanBayar,
                statusAktif: statusAktif,
                lunas: lunas,
                tanggalLunas: tanggalLunas,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagihanTable, TagihanData>(table),
                  $$TagihanTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({kategoriId = false, riwayatPembayaranRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (riwayatPembayaranRefs) db.riwayatPembayaran,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (kategoriId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.kategoriId,
                            referencedTable: $$TagihanTableReferences
                                ._kategoriIdTable(db),
                            referencedColumn: $$TagihanTableReferences
                                ._kategoriIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (riwayatPembayaranRefs)
                        await $_getPrefetchedData<
                          TagihanData,
                          $TagihanTable,
                          RiwayatPembayaranData
                        >(
                          currentTable: table,
                          referencedTable: $$TagihanTableReferences
                              ._riwayatPembayaranRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TagihanTableReferences(
                                db,
                                table,
                                p0,
                              ).riwayatPembayaranRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tagihanId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TagihanTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagihanTable,
      TagihanData,
      $$TagihanTableFilterComposer,
      $$TagihanTableOrderingComposer,
      $$TagihanTableAnnotationComposer,
      $$TagihanTableCreateCompanionBuilder,
      $$TagihanTableUpdateCompanionBuilder,
      (TagihanData, $$TagihanTableReferences),
      TagihanData,
      PrefetchHooks Function({bool kategoriId, bool riwayatPembayaranRefs})
    >;
typedef $$RiwayatPembayaranTableCreateCompanionBuilder =
    RiwayatPembayaranCompanion Function({
      Value<int> id,
      required int tagihanId,
      required DateTime periodeJatuhTempo,
      required int jumlahSen,
      Value<String> kodeMataUang,
      required DateTime tanggalBayar,
      Value<int?> telatHari,
      Value<String> via,
    });
typedef $$RiwayatPembayaranTableUpdateCompanionBuilder =
    RiwayatPembayaranCompanion Function({
      Value<int> id,
      Value<int> tagihanId,
      Value<DateTime> periodeJatuhTempo,
      Value<int> jumlahSen,
      Value<String> kodeMataUang,
      Value<DateTime> tanggalBayar,
      Value<int?> telatHari,
      Value<String> via,
    });

final class $$RiwayatPembayaranTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RiwayatPembayaranTable,
          RiwayatPembayaranData
        > {
  $$RiwayatPembayaranTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TagihanTable _tagihanIdTable(_$AppDatabase db) =>
      db.tagihan.createAlias('riwayat_pembayaran__tagihan_id__tagihan__id');

  $$TagihanTableProcessedTableManager get tagihanId {
    final $_column = $_itemColumn<int>('tagihan_id')!;

    final manager = $$TagihanTableTableManager(
      $_db,
      $_db.tagihan,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagihanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RiwayatPembayaranTableFilterComposer
    extends Composer<_$AppDatabase, $RiwayatPembayaranTable> {
  $$RiwayatPembayaranTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get periodeJatuhTempo => $composableBuilder(
    column: $table.periodeJatuhTempo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get jumlahSen => $composableBuilder(
    column: $table.jumlahSen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tanggalBayar => $composableBuilder(
    column: $table.tanggalBayar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get telatHari => $composableBuilder(
    column: $table.telatHari,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get via => $composableBuilder(
    column: $table.via,
    builder: (column) => ColumnFilters(column),
  );

  $$TagihanTableFilterComposer get tagihanId {
    final $$TagihanTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagihanId,
      referencedTable: $db.tagihan,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagihanTableFilterComposer(
            $db: $db,
            $table: $db.tagihan,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RiwayatPembayaranTableOrderingComposer
    extends Composer<_$AppDatabase, $RiwayatPembayaranTable> {
  $$RiwayatPembayaranTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get periodeJatuhTempo => $composableBuilder(
    column: $table.periodeJatuhTempo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get jumlahSen => $composableBuilder(
    column: $table.jumlahSen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tanggalBayar => $composableBuilder(
    column: $table.tanggalBayar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get telatHari => $composableBuilder(
    column: $table.telatHari,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get via => $composableBuilder(
    column: $table.via,
    builder: (column) => ColumnOrderings(column),
  );

  $$TagihanTableOrderingComposer get tagihanId {
    final $$TagihanTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagihanId,
      referencedTable: $db.tagihan,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagihanTableOrderingComposer(
            $db: $db,
            $table: $db.tagihan,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RiwayatPembayaranTableAnnotationComposer
    extends Composer<_$AppDatabase, $RiwayatPembayaranTable> {
  $$RiwayatPembayaranTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get periodeJatuhTempo => $composableBuilder(
    column: $table.periodeJatuhTempo,
    builder: (column) => column,
  );

  GeneratedColumn<int> get jumlahSen =>
      $composableBuilder(column: $table.jumlahSen, builder: (column) => column);

  GeneratedColumn<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get tanggalBayar => $composableBuilder(
    column: $table.tanggalBayar,
    builder: (column) => column,
  );

  GeneratedColumn<int> get telatHari =>
      $composableBuilder(column: $table.telatHari, builder: (column) => column);

  GeneratedColumn<String> get via =>
      $composableBuilder(column: $table.via, builder: (column) => column);

  $$TagihanTableAnnotationComposer get tagihanId {
    final $$TagihanTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagihanId,
      referencedTable: $db.tagihan,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagihanTableAnnotationComposer(
            $db: $db,
            $table: $db.tagihan,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RiwayatPembayaranTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RiwayatPembayaranTable,
          RiwayatPembayaranData,
          $$RiwayatPembayaranTableFilterComposer,
          $$RiwayatPembayaranTableOrderingComposer,
          $$RiwayatPembayaranTableAnnotationComposer,
          $$RiwayatPembayaranTableCreateCompanionBuilder,
          $$RiwayatPembayaranTableUpdateCompanionBuilder,
          (RiwayatPembayaranData, $$RiwayatPembayaranTableReferences),
          RiwayatPembayaranData,
          PrefetchHooks Function({bool tagihanId})
        > {
  $$RiwayatPembayaranTableTableManager(
    _$AppDatabase db,
    $RiwayatPembayaranTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RiwayatPembayaranTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RiwayatPembayaranTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RiwayatPembayaranTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> tagihanId = const Value.absent(),
                Value<DateTime> periodeJatuhTempo = const Value.absent(),
                Value<int> jumlahSen = const Value.absent(),
                Value<String> kodeMataUang = const Value.absent(),
                Value<DateTime> tanggalBayar = const Value.absent(),
                Value<int?> telatHari = const Value.absent(),
                Value<String> via = const Value.absent(),
              }) => RiwayatPembayaranCompanion(
                id: id,
                tagihanId: tagihanId,
                periodeJatuhTempo: periodeJatuhTempo,
                jumlahSen: jumlahSen,
                kodeMataUang: kodeMataUang,
                tanggalBayar: tanggalBayar,
                telatHari: telatHari,
                via: via,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int tagihanId,
                required DateTime periodeJatuhTempo,
                required int jumlahSen,
                Value<String> kodeMataUang = const Value.absent(),
                required DateTime tanggalBayar,
                Value<int?> telatHari = const Value.absent(),
                Value<String> via = const Value.absent(),
              }) => RiwayatPembayaranCompanion.insert(
                id: id,
                tagihanId: tagihanId,
                periodeJatuhTempo: periodeJatuhTempo,
                jumlahSen: jumlahSen,
                kodeMataUang: kodeMataUang,
                tanggalBayar: tanggalBayar,
                telatHari: telatHari,
                via: via,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RiwayatPembayaranTable, RiwayatPembayaranData>(
                    table,
                  ),
                  $$RiwayatPembayaranTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tagihanId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tagihanId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagihanId,
                        referencedTable: $$RiwayatPembayaranTableReferences
                            ._tagihanIdTable(db),
                        referencedColumn: $$RiwayatPembayaranTableReferences
                            ._tagihanIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RiwayatPembayaranTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RiwayatPembayaranTable,
      RiwayatPembayaranData,
      $$RiwayatPembayaranTableFilterComposer,
      $$RiwayatPembayaranTableOrderingComposer,
      $$RiwayatPembayaranTableAnnotationComposer,
      $$RiwayatPembayaranTableCreateCompanionBuilder,
      $$RiwayatPembayaranTableUpdateCompanionBuilder,
      (RiwayatPembayaranData, $$RiwayatPembayaranTableReferences),
      RiwayatPembayaranData,
      PrefetchHooks Function({bool tagihanId})
    >;
typedef $$PemasukanBulananTableCreateCompanionBuilder =
    PemasukanBulananCompanion Function({
      Value<int> id,
      required String bulan,
      Value<int> jumlahSen,
      Value<String> sumber,
    });
typedef $$PemasukanBulananTableUpdateCompanionBuilder =
    PemasukanBulananCompanion Function({
      Value<int> id,
      Value<String> bulan,
      Value<int> jumlahSen,
      Value<String> sumber,
    });

class $$PemasukanBulananTableFilterComposer
    extends Composer<_$AppDatabase, $PemasukanBulananTable> {
  $$PemasukanBulananTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bulan => $composableBuilder(
    column: $table.bulan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get jumlahSen => $composableBuilder(
    column: $table.jumlahSen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sumber => $composableBuilder(
    column: $table.sumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PemasukanBulananTableOrderingComposer
    extends Composer<_$AppDatabase, $PemasukanBulananTable> {
  $$PemasukanBulananTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bulan => $composableBuilder(
    column: $table.bulan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get jumlahSen => $composableBuilder(
    column: $table.jumlahSen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sumber => $composableBuilder(
    column: $table.sumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PemasukanBulananTableAnnotationComposer
    extends Composer<_$AppDatabase, $PemasukanBulananTable> {
  $$PemasukanBulananTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bulan =>
      $composableBuilder(column: $table.bulan, builder: (column) => column);

  GeneratedColumn<int> get jumlahSen =>
      $composableBuilder(column: $table.jumlahSen, builder: (column) => column);

  GeneratedColumn<String> get sumber =>
      $composableBuilder(column: $table.sumber, builder: (column) => column);
}

class $$PemasukanBulananTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PemasukanBulananTable,
          PemasukanBulananData,
          $$PemasukanBulananTableFilterComposer,
          $$PemasukanBulananTableOrderingComposer,
          $$PemasukanBulananTableAnnotationComposer,
          $$PemasukanBulananTableCreateCompanionBuilder,
          $$PemasukanBulananTableUpdateCompanionBuilder,
          (
            PemasukanBulananData,
            BaseReferences<
              _$AppDatabase,
              $PemasukanBulananTable,
              PemasukanBulananData
            >,
          ),
          PemasukanBulananData,
          PrefetchHooks Function()
        > {
  $$PemasukanBulananTableTableManager(
    _$AppDatabase db,
    $PemasukanBulananTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PemasukanBulananTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PemasukanBulananTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PemasukanBulananTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bulan = const Value.absent(),
                Value<int> jumlahSen = const Value.absent(),
                Value<String> sumber = const Value.absent(),
              }) => PemasukanBulananCompanion(
                id: id,
                bulan: bulan,
                jumlahSen: jumlahSen,
                sumber: sumber,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bulan,
                Value<int> jumlahSen = const Value.absent(),
                Value<String> sumber = const Value.absent(),
              }) => PemasukanBulananCompanion.insert(
                id: id,
                bulan: bulan,
                jumlahSen: jumlahSen,
                sumber: sumber,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PemasukanBulananTable, PemasukanBulananData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $PemasukanBulananTable,
                    PemasukanBulananData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PemasukanBulananTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PemasukanBulananTable,
      PemasukanBulananData,
      $$PemasukanBulananTableFilterComposer,
      $$PemasukanBulananTableOrderingComposer,
      $$PemasukanBulananTableAnnotationComposer,
      $$PemasukanBulananTableCreateCompanionBuilder,
      $$PemasukanBulananTableUpdateCompanionBuilder,
      (
        PemasukanBulananData,
        BaseReferences<
          _$AppDatabase,
          $PemasukanBulananTable,
          PemasukanBulananData
        >,
      ),
      PemasukanBulananData,
      PrefetchHooks Function()
    >;
typedef $$PengaturanTableCreateCompanionBuilder = PengaturanCompanion Function({
  required String kunci,
  required String nilai,
  Value<int> rowid,
});
typedef $$PengaturanTableUpdateCompanionBuilder = PengaturanCompanion Function({
  Value<String> kunci,
  Value<String> nilai,
  Value<int> rowid,
});

class $$PengaturanTableFilterComposer
    extends Composer<_$AppDatabase, $PengaturanTable> {
  $$PengaturanTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kunci => $composableBuilder(
    column: $table.kunci,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nilai => $composableBuilder(
    column: $table.nilai,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PengaturanTableOrderingComposer
    extends Composer<_$AppDatabase, $PengaturanTable> {
  $$PengaturanTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kunci => $composableBuilder(
    column: $table.kunci,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nilai => $composableBuilder(
    column: $table.nilai,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PengaturanTableAnnotationComposer
    extends Composer<_$AppDatabase, $PengaturanTable> {
  $$PengaturanTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kunci =>
      $composableBuilder(column: $table.kunci, builder: (column) => column);

  GeneratedColumn<String> get nilai =>
      $composableBuilder(column: $table.nilai, builder: (column) => column);
}

class $$PengaturanTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PengaturanTable,
          PengaturanData,
          $$PengaturanTableFilterComposer,
          $$PengaturanTableOrderingComposer,
          $$PengaturanTableAnnotationComposer,
          $$PengaturanTableCreateCompanionBuilder,
          $$PengaturanTableUpdateCompanionBuilder,
          (
            PengaturanData,
            BaseReferences<_$AppDatabase, $PengaturanTable, PengaturanData>,
          ),
          PengaturanData,
          PrefetchHooks Function()
        > {
  $$PengaturanTableTableManager(_$AppDatabase db, $PengaturanTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PengaturanTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PengaturanTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PengaturanTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> kunci = const Value.absent(),
            Value<String> nilai = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PengaturanCompanion(kunci: kunci, nilai: nilai, rowid: rowid),
          createCompanionCallback:
              ({
                required String kunci,
                required String nilai,
                Value<int> rowid = const Value.absent(),
              }) => PengaturanCompanion.insert(
                kunci: kunci,
                nilai: nilai,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PengaturanTable, PengaturanData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PengaturanTable,
                    PengaturanData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PengaturanTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PengaturanTable,
      PengaturanData,
      $$PengaturanTableFilterComposer,
      $$PengaturanTableOrderingComposer,
      $$PengaturanTableAnnotationComposer,
      $$PengaturanTableCreateCompanionBuilder,
      $$PengaturanTableUpdateCompanionBuilder,
      (
        PengaturanData,
        BaseReferences<_$AppDatabase, $PengaturanTable, PengaturanData>,
      ),
      PengaturanData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$KategoriTableTableManager get kategori =>
      $$KategoriTableTableManager(_db, _db.kategori);
  $$TagihanTableTableManager get tagihan =>
      $$TagihanTableTableManager(_db, _db.tagihan);
  $$RiwayatPembayaranTableTableManager get riwayatPembayaran =>
      $$RiwayatPembayaranTableTableManager(_db, _db.riwayatPembayaran);
  $$PemasukanBulananTableTableManager get pemasukanBulanan =>
      $$PemasukanBulananTableTableManager(_db, _db.pemasukanBulanan);
  $$PengaturanTableTableManager get pengaturan =>
      $$PengaturanTableTableManager(_db, _db.pengaturan);
}
