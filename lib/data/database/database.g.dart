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

class $KategoriTransaksiTable extends KategoriTransaksi
    with TableInfo<$KategoriTransaksiTable, KategoriTransaksiData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KategoriTransaksiTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _kodeMeta = const VerificationMeta('kode');
  @override
  late final GeneratedColumn<String> kode = GeneratedColumn<String>(
    'kode',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _indukKodeMeta = const VerificationMeta(
    'indukKode',
  );
  @override
  late final GeneratedColumn<String> indukKode = GeneratedColumn<String>(
    'induk_kode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _jenisMeta = const VerificationMeta('jenis');
  @override
  late final GeneratedColumn<String> jenis = GeneratedColumn<String>(
    'jenis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pengeluaran'),
  );
  static const VerificationMeta _ikonMeta = const VerificationMeta('ikon');
  @override
  late final GeneratedColumn<String> ikon = GeneratedColumn<String>(
    'ikon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('category'),
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
  static const VerificationMeta _sifatArusMeta = const VerificationMeta(
    'sifatArus',
  );
  @override
  late final GeneratedColumn<String> sifatArus = GeneratedColumn<String>(
    'sifat_arus',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('campuran'),
  );
  static const VerificationMeta _bawaanSistemMeta = const VerificationMeta(
    'bawaanSistem',
  );
  @override
  late final GeneratedColumn<bool> bawaanSistem = GeneratedColumn<bool>(
    'bawaan_sistem',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("bawaan_sistem" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _arsipMeta = const VerificationMeta('arsip');
  @override
  late final GeneratedColumn<bool> arsip = GeneratedColumn<bool>(
    'arsip',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("arsip" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    kode,
    indukKode,
    nama,
    jenis,
    ikon,
    warna,
    urutan,
    sifatArus,
    bawaanSistem,
    arsip,
    dibuatPada,
    diubahPada,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kategori_transaksi';
  @override
  VerificationContext validateIntegrity(
    Insertable<KategoriTransaksiData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kode')) {
      context.handle(
        _kodeMeta,
        kode.isAcceptableOrUnknown(data['kode']!, _kodeMeta),
      );
    } else if (isInserting) {
      context.missing(_kodeMeta);
    }
    if (data.containsKey('induk_kode')) {
      context.handle(
        _indukKodeMeta,
        indukKode.isAcceptableOrUnknown(data['induk_kode']!, _indukKodeMeta),
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
    if (data.containsKey('jenis')) {
      context.handle(
        _jenisMeta,
        jenis.isAcceptableOrUnknown(data['jenis']!, _jenisMeta),
      );
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
    if (data.containsKey('sifat_arus')) {
      context.handle(
        _sifatArusMeta,
        sifatArus.isAcceptableOrUnknown(data['sifat_arus']!, _sifatArusMeta),
      );
    }
    if (data.containsKey('bawaan_sistem')) {
      context.handle(
        _bawaanSistemMeta,
        bawaanSistem.isAcceptableOrUnknown(
          data['bawaan_sistem']!,
          _bawaanSistemMeta,
        ),
      );
    }
    if (data.containsKey('arsip')) {
      context.handle(
        _arsipMeta,
        arsip.isAcceptableOrUnknown(data['arsip']!, _arsipMeta),
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
  KategoriTransaksiData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KategoriTransaksiData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kode'],
      )!,
      indukKode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}induk_kode'],
      ),
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      jenis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jenis'],
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
      sifatArus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sifat_arus'],
      )!,
      bawaanSistem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}bawaan_sistem'],
      )!,
      arsip: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}arsip'],
      )!,
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
  $KategoriTransaksiTable createAlias(String alias) {
    return $KategoriTransaksiTable(attachedDatabase, alias);
  }
}

class KategoriTransaksiData extends DataClass
    implements Insertable<KategoriTransaksiData> {
  final int id;

  /// Kunci stabil (mis. `kel_makan`) — dipakai seed ulang & impor/ekspor.
  /// Tanpa kolom ini, kategori berganda setiap kali nama diubah pengguna.
  final String kode;

  /// Kode induk untuk sub-kategori; null = kategori tingkat atas.
  /// (Sub-kategori belum di-seed di V1.5 — kolom ini menyiapkannya.)
  final String? indukKode;
  final String nama;

  /// `pengeluaran` / `pemasukan` (JenisArus di lib/data/model/enums.dart).
  final String jenis;
  final String ikon;
  final String warna;
  final int urutan;

  /// `berulang` / `sekali` / `campuran` — bahan awal FR-68 (pemilihan
  /// kategori berulang). Nilai mengikuti daftar kategori Indonesia.
  final String sifatArus;

  /// true = kategori bawaan: tidak boleh dihapus, hanya bisa disembunyikan.
  final bool bawaanSistem;

  /// true = disembunyikan dari daftar tanpa menghapus riwayat transaksi.
  final bool arsip;
  final DateTime dibuatPada;
  final DateTime diubahPada;
  const KategoriTransaksiData({
    required this.id,
    required this.kode,
    this.indukKode,
    required this.nama,
    required this.jenis,
    required this.ikon,
    required this.warna,
    required this.urutan,
    required this.sifatArus,
    required this.bawaanSistem,
    required this.arsip,
    required this.dibuatPada,
    required this.diubahPada,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kode'] = Variable<String>(kode);
    if (!nullToAbsent || indukKode != null) {
      map['induk_kode'] = Variable<String>(indukKode);
    }
    map['nama'] = Variable<String>(nama);
    map['jenis'] = Variable<String>(jenis);
    map['ikon'] = Variable<String>(ikon);
    map['warna'] = Variable<String>(warna);
    map['urutan'] = Variable<int>(urutan);
    map['sifat_arus'] = Variable<String>(sifatArus);
    map['bawaan_sistem'] = Variable<bool>(bawaanSistem);
    map['arsip'] = Variable<bool>(arsip);
    map['dibuat_pada'] = Variable<DateTime>(dibuatPada);
    map['diubah_pada'] = Variable<DateTime>(diubahPada);
    return map;
  }

  KategoriTransaksiCompanion toCompanion(bool nullToAbsent) {
    return KategoriTransaksiCompanion(
      id: Value(id),
      kode: Value(kode),
      indukKode: indukKode == null && nullToAbsent
          ? const Value.absent()
          : Value(indukKode),
      nama: Value(nama),
      jenis: Value(jenis),
      ikon: Value(ikon),
      warna: Value(warna),
      urutan: Value(urutan),
      sifatArus: Value(sifatArus),
      bawaanSistem: Value(bawaanSistem),
      arsip: Value(arsip),
      dibuatPada: Value(dibuatPada),
      diubahPada: Value(diubahPada),
    );
  }

  factory KategoriTransaksiData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KategoriTransaksiData(
      id: serializer.fromJson<int>(json['id']),
      kode: serializer.fromJson<String>(json['kode']),
      indukKode: serializer.fromJson<String?>(json['indukKode']),
      nama: serializer.fromJson<String>(json['nama']),
      jenis: serializer.fromJson<String>(json['jenis']),
      ikon: serializer.fromJson<String>(json['ikon']),
      warna: serializer.fromJson<String>(json['warna']),
      urutan: serializer.fromJson<int>(json['urutan']),
      sifatArus: serializer.fromJson<String>(json['sifatArus']),
      bawaanSistem: serializer.fromJson<bool>(json['bawaanSistem']),
      arsip: serializer.fromJson<bool>(json['arsip']),
      dibuatPada: serializer.fromJson<DateTime>(json['dibuatPada']),
      diubahPada: serializer.fromJson<DateTime>(json['diubahPada']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kode': serializer.toJson<String>(kode),
      'indukKode': serializer.toJson<String?>(indukKode),
      'nama': serializer.toJson<String>(nama),
      'jenis': serializer.toJson<String>(jenis),
      'ikon': serializer.toJson<String>(ikon),
      'warna': serializer.toJson<String>(warna),
      'urutan': serializer.toJson<int>(urutan),
      'sifatArus': serializer.toJson<String>(sifatArus),
      'bawaanSistem': serializer.toJson<bool>(bawaanSistem),
      'arsip': serializer.toJson<bool>(arsip),
      'dibuatPada': serializer.toJson<DateTime>(dibuatPada),
      'diubahPada': serializer.toJson<DateTime>(diubahPada),
    };
  }

  KategoriTransaksiData copyWith({
    int? id,
    String? kode,
    Value<String?> indukKode = const Value.absent(),
    String? nama,
    String? jenis,
    String? ikon,
    String? warna,
    int? urutan,
    String? sifatArus,
    bool? bawaanSistem,
    bool? arsip,
    DateTime? dibuatPada,
    DateTime? diubahPada,
  }) => KategoriTransaksiData(
    id: id ?? this.id,
    kode: kode ?? this.kode,
    indukKode: indukKode.present ? indukKode.value : this.indukKode,
    nama: nama ?? this.nama,
    jenis: jenis ?? this.jenis,
    ikon: ikon ?? this.ikon,
    warna: warna ?? this.warna,
    urutan: urutan ?? this.urutan,
    sifatArus: sifatArus ?? this.sifatArus,
    bawaanSistem: bawaanSistem ?? this.bawaanSistem,
    arsip: arsip ?? this.arsip,
    dibuatPada: dibuatPada ?? this.dibuatPada,
    diubahPada: diubahPada ?? this.diubahPada,
  );
  KategoriTransaksiData copyWithCompanion(KategoriTransaksiCompanion data) {
    return KategoriTransaksiData(
      id: data.id.present ? data.id.value : this.id,
      kode: data.kode.present ? data.kode.value : this.kode,
      indukKode: data.indukKode.present ? data.indukKode.value : this.indukKode,
      nama: data.nama.present ? data.nama.value : this.nama,
      jenis: data.jenis.present ? data.jenis.value : this.jenis,
      ikon: data.ikon.present ? data.ikon.value : this.ikon,
      warna: data.warna.present ? data.warna.value : this.warna,
      urutan: data.urutan.present ? data.urutan.value : this.urutan,
      sifatArus: data.sifatArus.present ? data.sifatArus.value : this.sifatArus,
      bawaanSistem: data.bawaanSistem.present
          ? data.bawaanSistem.value
          : this.bawaanSistem,
      arsip: data.arsip.present ? data.arsip.value : this.arsip,
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
    return (StringBuffer('KategoriTransaksiData(')
          ..write('id: $id, ')
          ..write('kode: $kode, ')
          ..write('indukKode: $indukKode, ')
          ..write('nama: $nama, ')
          ..write('jenis: $jenis, ')
          ..write('ikon: $ikon, ')
          ..write('warna: $warna, ')
          ..write('urutan: $urutan, ')
          ..write('sifatArus: $sifatArus, ')
          ..write('bawaanSistem: $bawaanSistem, ')
          ..write('arsip: $arsip, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kode,
    indukKode,
    nama,
    jenis,
    ikon,
    warna,
    urutan,
    sifatArus,
    bawaanSistem,
    arsip,
    dibuatPada,
    diubahPada,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KategoriTransaksiData &&
          other.id == this.id &&
          other.kode == this.kode &&
          other.indukKode == this.indukKode &&
          other.nama == this.nama &&
          other.jenis == this.jenis &&
          other.ikon == this.ikon &&
          other.warna == this.warna &&
          other.urutan == this.urutan &&
          other.sifatArus == this.sifatArus &&
          other.bawaanSistem == this.bawaanSistem &&
          other.arsip == this.arsip &&
          other.dibuatPada == this.dibuatPada &&
          other.diubahPada == this.diubahPada);
}

class KategoriTransaksiCompanion
    extends UpdateCompanion<KategoriTransaksiData> {
  final Value<int> id;
  final Value<String> kode;
  final Value<String?> indukKode;
  final Value<String> nama;
  final Value<String> jenis;
  final Value<String> ikon;
  final Value<String> warna;
  final Value<int> urutan;
  final Value<String> sifatArus;
  final Value<bool> bawaanSistem;
  final Value<bool> arsip;
  final Value<DateTime> dibuatPada;
  final Value<DateTime> diubahPada;
  const KategoriTransaksiCompanion({
    this.id = const Value.absent(),
    this.kode = const Value.absent(),
    this.indukKode = const Value.absent(),
    this.nama = const Value.absent(),
    this.jenis = const Value.absent(),
    this.ikon = const Value.absent(),
    this.warna = const Value.absent(),
    this.urutan = const Value.absent(),
    this.sifatArus = const Value.absent(),
    this.bawaanSistem = const Value.absent(),
    this.arsip = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  });
  KategoriTransaksiCompanion.insert({
    this.id = const Value.absent(),
    required String kode,
    this.indukKode = const Value.absent(),
    required String nama,
    this.jenis = const Value.absent(),
    this.ikon = const Value.absent(),
    this.warna = const Value.absent(),
    this.urutan = const Value.absent(),
    this.sifatArus = const Value.absent(),
    this.bawaanSistem = const Value.absent(),
    this.arsip = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  }) : kode = Value(kode),
       nama = Value(nama);
  static Insertable<KategoriTransaksiData> custom({
    Expression<int>? id,
    Expression<String>? kode,
    Expression<String>? indukKode,
    Expression<String>? nama,
    Expression<String>? jenis,
    Expression<String>? ikon,
    Expression<String>? warna,
    Expression<int>? urutan,
    Expression<String>? sifatArus,
    Expression<bool>? bawaanSistem,
    Expression<bool>? arsip,
    Expression<DateTime>? dibuatPada,
    Expression<DateTime>? diubahPada,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kode != null) 'kode': kode,
      if (indukKode != null) 'induk_kode': indukKode,
      if (nama != null) 'nama': nama,
      if (jenis != null) 'jenis': jenis,
      if (ikon != null) 'ikon': ikon,
      if (warna != null) 'warna': warna,
      if (urutan != null) 'urutan': urutan,
      if (sifatArus != null) 'sifat_arus': sifatArus,
      if (bawaanSistem != null) 'bawaan_sistem': bawaanSistem,
      if (arsip != null) 'arsip': arsip,
      if (dibuatPada != null) 'dibuat_pada': dibuatPada,
      if (diubahPada != null) 'diubah_pada': diubahPada,
    });
  }

  KategoriTransaksiCompanion copyWith({
    Value<int>? id,
    Value<String>? kode,
    Value<String?>? indukKode,
    Value<String>? nama,
    Value<String>? jenis,
    Value<String>? ikon,
    Value<String>? warna,
    Value<int>? urutan,
    Value<String>? sifatArus,
    Value<bool>? bawaanSistem,
    Value<bool>? arsip,
    Value<DateTime>? dibuatPada,
    Value<DateTime>? diubahPada,
  }) {
    return KategoriTransaksiCompanion(
      id: id ?? this.id,
      kode: kode ?? this.kode,
      indukKode: indukKode ?? this.indukKode,
      nama: nama ?? this.nama,
      jenis: jenis ?? this.jenis,
      ikon: ikon ?? this.ikon,
      warna: warna ?? this.warna,
      urutan: urutan ?? this.urutan,
      sifatArus: sifatArus ?? this.sifatArus,
      bawaanSistem: bawaanSistem ?? this.bawaanSistem,
      arsip: arsip ?? this.arsip,
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
    if (kode.present) {
      map['kode'] = Variable<String>(kode.value);
    }
    if (indukKode.present) {
      map['induk_kode'] = Variable<String>(indukKode.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (jenis.present) {
      map['jenis'] = Variable<String>(jenis.value);
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
    if (sifatArus.present) {
      map['sifat_arus'] = Variable<String>(sifatArus.value);
    }
    if (bawaanSistem.present) {
      map['bawaan_sistem'] = Variable<bool>(bawaanSistem.value);
    }
    if (arsip.present) {
      map['arsip'] = Variable<bool>(arsip.value);
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
    return (StringBuffer('KategoriTransaksiCompanion(')
          ..write('id: $id, ')
          ..write('kode: $kode, ')
          ..write('indukKode: $indukKode, ')
          ..write('nama: $nama, ')
          ..write('jenis: $jenis, ')
          ..write('ikon: $ikon, ')
          ..write('warna: $warna, ')
          ..write('urutan: $urutan, ')
          ..write('sifatArus: $sifatArus, ')
          ..write('bawaanSistem: $bawaanSistem, ')
          ..write('arsip: $arsip, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }
}

class $TransaksiTable extends Transaksi
    with TableInfo<$TransaksiTable, TransaksiData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransaksiTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _idTransaksiMeta = const VerificationMeta(
    'idTransaksi',
  );
  @override
  late final GeneratedColumn<String> idTransaksi = GeneratedColumn<String>(
    'id_transaksi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jenisMeta = const VerificationMeta('jenis');
  @override
  late final GeneratedColumn<String> jenis = GeneratedColumn<String>(
    'jenis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pengeluaran'),
  );
  static const VerificationMeta _tanggalMeta = const VerificationMeta(
    'tanggal',
  );
  @override
  late final GeneratedColumn<DateTime> tanggal = GeneratedColumn<DateTime>(
    'tanggal',
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
      'REFERENCES kategori_transaksi (id)',
    ),
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
  static const VerificationMeta _sumberMeta = const VerificationMeta('sumber');
  @override
  late final GeneratedColumn<String> sumber = GeneratedColumn<String>(
    'sumber',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _tagihanIdMeta = const VerificationMeta(
    'tagihanId',
  );
  @override
  late final GeneratedColumn<int> tagihanId = GeneratedColumn<int>(
    'tagihan_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tagihan (id)',
    ),
  );
  static const VerificationMeta _periodeTagihanMeta = const VerificationMeta(
    'periodeTagihan',
  );
  @override
  late final GeneratedColumn<String> periodeTagihan = GeneratedColumn<String>(
    'periode_tagihan',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    idTransaksi,
    jenis,
    tanggal,
    jumlahSen,
    kodeMataUang,
    kategoriId,
    catatan,
    sumber,
    tagihanId,
    periodeTagihan,
    dibuatPada,
    diubahPada,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaksi';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransaksiData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('id_transaksi')) {
      context.handle(
        _idTransaksiMeta,
        idTransaksi.isAcceptableOrUnknown(
          data['id_transaksi']!,
          _idTransaksiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idTransaksiMeta);
    }
    if (data.containsKey('jenis')) {
      context.handle(
        _jenisMeta,
        jenis.isAcceptableOrUnknown(data['jenis']!, _jenisMeta),
      );
    }
    if (data.containsKey('tanggal')) {
      context.handle(
        _tanggalMeta,
        tanggal.isAcceptableOrUnknown(data['tanggal']!, _tanggalMeta),
      );
    } else if (isInserting) {
      context.missing(_tanggalMeta);
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
    if (data.containsKey('kategori_id')) {
      context.handle(
        _kategoriIdMeta,
        kategoriId.isAcceptableOrUnknown(data['kategori_id']!, _kategoriIdMeta),
      );
    }
    if (data.containsKey('catatan')) {
      context.handle(
        _catatanMeta,
        catatan.isAcceptableOrUnknown(data['catatan']!, _catatanMeta),
      );
    }
    if (data.containsKey('sumber')) {
      context.handle(
        _sumberMeta,
        sumber.isAcceptableOrUnknown(data['sumber']!, _sumberMeta),
      );
    }
    if (data.containsKey('tagihan_id')) {
      context.handle(
        _tagihanIdMeta,
        tagihanId.isAcceptableOrUnknown(data['tagihan_id']!, _tagihanIdMeta),
      );
    }
    if (data.containsKey('periode_tagihan')) {
      context.handle(
        _periodeTagihanMeta,
        periodeTagihan.isAcceptableOrUnknown(
          data['periode_tagihan']!,
          _periodeTagihanMeta,
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
  TransaksiData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransaksiData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      idTransaksi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id_transaksi'],
      )!,
      jenis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jenis'],
      )!,
      tanggal: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tanggal'],
      )!,
      jumlahSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}jumlah_sen'],
      )!,
      kodeMataUang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kode_mata_uang'],
      )!,
      kategoriId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kategori_id'],
      ),
      catatan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catatan'],
      ),
      sumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sumber'],
      )!,
      tagihanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tagihan_id'],
      ),
      periodeTagihan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}periode_tagihan'],
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
  $TransaksiTable createAlias(String alias) {
    return $TransaksiTable(attachedDatabase, alias);
  }
}

class TransaksiData extends DataClass implements Insertable<TransaksiData> {
  final int id;

  /// Pengenal stabil (`trx_<uuid>` / `tagihan:<id>:<YYYY-MM>`) — kunci
  /// idempotensi impor & sinkron (pola PB-05/06/07).
  final String idTransaksi;

  /// `pengeluaran` / `pemasukan`.
  final String jenis;

  /// Tanggal kejadian; jam diabaikan (disimpan tengah malam lokal).
  final DateTime tanggal;

  /// Selalu positif; arah ditentukan [jenis]. Satuan sen.
  final int jumlahSen;
  final String kodeMataUang;
  final int? kategoriId;
  final String? catatan;

  /// `manual` / `impor` / `dari_tagihan` / `berulang`.
  final String sumber;

  /// Tautan ke pelunasan tagihan (bahan FR-73). Tanpa cascade: transaksi
  /// tetap ada walau tagihannya dihapus (nilai dikosongkan, riwayat utuh).
  final int? tagihanId;

  /// 'YYYY-MM' periode tagihan yang dibayar, bila [tagihanId] terisi.
  final String? periodeTagihan;
  final DateTime dibuatPada;
  final DateTime diubahPada;
  const TransaksiData({
    required this.id,
    required this.idTransaksi,
    required this.jenis,
    required this.tanggal,
    required this.jumlahSen,
    required this.kodeMataUang,
    this.kategoriId,
    this.catatan,
    required this.sumber,
    this.tagihanId,
    this.periodeTagihan,
    required this.dibuatPada,
    required this.diubahPada,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['id_transaksi'] = Variable<String>(idTransaksi);
    map['jenis'] = Variable<String>(jenis);
    map['tanggal'] = Variable<DateTime>(tanggal);
    map['jumlah_sen'] = Variable<int>(jumlahSen);
    map['kode_mata_uang'] = Variable<String>(kodeMataUang);
    if (!nullToAbsent || kategoriId != null) {
      map['kategori_id'] = Variable<int>(kategoriId);
    }
    if (!nullToAbsent || catatan != null) {
      map['catatan'] = Variable<String>(catatan);
    }
    map['sumber'] = Variable<String>(sumber);
    if (!nullToAbsent || tagihanId != null) {
      map['tagihan_id'] = Variable<int>(tagihanId);
    }
    if (!nullToAbsent || periodeTagihan != null) {
      map['periode_tagihan'] = Variable<String>(periodeTagihan);
    }
    map['dibuat_pada'] = Variable<DateTime>(dibuatPada);
    map['diubah_pada'] = Variable<DateTime>(diubahPada);
    return map;
  }

  TransaksiCompanion toCompanion(bool nullToAbsent) {
    return TransaksiCompanion(
      id: Value(id),
      idTransaksi: Value(idTransaksi),
      jenis: Value(jenis),
      tanggal: Value(tanggal),
      jumlahSen: Value(jumlahSen),
      kodeMataUang: Value(kodeMataUang),
      kategoriId: kategoriId == null && nullToAbsent
          ? const Value.absent()
          : Value(kategoriId),
      catatan: catatan == null && nullToAbsent
          ? const Value.absent()
          : Value(catatan),
      sumber: Value(sumber),
      tagihanId: tagihanId == null && nullToAbsent
          ? const Value.absent()
          : Value(tagihanId),
      periodeTagihan: periodeTagihan == null && nullToAbsent
          ? const Value.absent()
          : Value(periodeTagihan),
      dibuatPada: Value(dibuatPada),
      diubahPada: Value(diubahPada),
    );
  }

  factory TransaksiData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransaksiData(
      id: serializer.fromJson<int>(json['id']),
      idTransaksi: serializer.fromJson<String>(json['idTransaksi']),
      jenis: serializer.fromJson<String>(json['jenis']),
      tanggal: serializer.fromJson<DateTime>(json['tanggal']),
      jumlahSen: serializer.fromJson<int>(json['jumlahSen']),
      kodeMataUang: serializer.fromJson<String>(json['kodeMataUang']),
      kategoriId: serializer.fromJson<int?>(json['kategoriId']),
      catatan: serializer.fromJson<String?>(json['catatan']),
      sumber: serializer.fromJson<String>(json['sumber']),
      tagihanId: serializer.fromJson<int?>(json['tagihanId']),
      periodeTagihan: serializer.fromJson<String?>(json['periodeTagihan']),
      dibuatPada: serializer.fromJson<DateTime>(json['dibuatPada']),
      diubahPada: serializer.fromJson<DateTime>(json['diubahPada']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'idTransaksi': serializer.toJson<String>(idTransaksi),
      'jenis': serializer.toJson<String>(jenis),
      'tanggal': serializer.toJson<DateTime>(tanggal),
      'jumlahSen': serializer.toJson<int>(jumlahSen),
      'kodeMataUang': serializer.toJson<String>(kodeMataUang),
      'kategoriId': serializer.toJson<int?>(kategoriId),
      'catatan': serializer.toJson<String?>(catatan),
      'sumber': serializer.toJson<String>(sumber),
      'tagihanId': serializer.toJson<int?>(tagihanId),
      'periodeTagihan': serializer.toJson<String?>(periodeTagihan),
      'dibuatPada': serializer.toJson<DateTime>(dibuatPada),
      'diubahPada': serializer.toJson<DateTime>(diubahPada),
    };
  }

  TransaksiData copyWith({
    int? id,
    String? idTransaksi,
    String? jenis,
    DateTime? tanggal,
    int? jumlahSen,
    String? kodeMataUang,
    Value<int?> kategoriId = const Value.absent(),
    Value<String?> catatan = const Value.absent(),
    String? sumber,
    Value<int?> tagihanId = const Value.absent(),
    Value<String?> periodeTagihan = const Value.absent(),
    DateTime? dibuatPada,
    DateTime? diubahPada,
  }) => TransaksiData(
    id: id ?? this.id,
    idTransaksi: idTransaksi ?? this.idTransaksi,
    jenis: jenis ?? this.jenis,
    tanggal: tanggal ?? this.tanggal,
    jumlahSen: jumlahSen ?? this.jumlahSen,
    kodeMataUang: kodeMataUang ?? this.kodeMataUang,
    kategoriId: kategoriId.present ? kategoriId.value : this.kategoriId,
    catatan: catatan.present ? catatan.value : this.catatan,
    sumber: sumber ?? this.sumber,
    tagihanId: tagihanId.present ? tagihanId.value : this.tagihanId,
    periodeTagihan: periodeTagihan.present
        ? periodeTagihan.value
        : this.periodeTagihan,
    dibuatPada: dibuatPada ?? this.dibuatPada,
    diubahPada: diubahPada ?? this.diubahPada,
  );
  TransaksiData copyWithCompanion(TransaksiCompanion data) {
    return TransaksiData(
      id: data.id.present ? data.id.value : this.id,
      idTransaksi: data.idTransaksi.present
          ? data.idTransaksi.value
          : this.idTransaksi,
      jenis: data.jenis.present ? data.jenis.value : this.jenis,
      tanggal: data.tanggal.present ? data.tanggal.value : this.tanggal,
      jumlahSen: data.jumlahSen.present ? data.jumlahSen.value : this.jumlahSen,
      kodeMataUang: data.kodeMataUang.present
          ? data.kodeMataUang.value
          : this.kodeMataUang,
      kategoriId: data.kategoriId.present
          ? data.kategoriId.value
          : this.kategoriId,
      catatan: data.catatan.present ? data.catatan.value : this.catatan,
      sumber: data.sumber.present ? data.sumber.value : this.sumber,
      tagihanId: data.tagihanId.present ? data.tagihanId.value : this.tagihanId,
      periodeTagihan: data.periodeTagihan.present
          ? data.periodeTagihan.value
          : this.periodeTagihan,
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
    return (StringBuffer('TransaksiData(')
          ..write('id: $id, ')
          ..write('idTransaksi: $idTransaksi, ')
          ..write('jenis: $jenis, ')
          ..write('tanggal: $tanggal, ')
          ..write('jumlahSen: $jumlahSen, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('kategoriId: $kategoriId, ')
          ..write('catatan: $catatan, ')
          ..write('sumber: $sumber, ')
          ..write('tagihanId: $tagihanId, ')
          ..write('periodeTagihan: $periodeTagihan, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    idTransaksi,
    jenis,
    tanggal,
    jumlahSen,
    kodeMataUang,
    kategoriId,
    catatan,
    sumber,
    tagihanId,
    periodeTagihan,
    dibuatPada,
    diubahPada,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransaksiData &&
          other.id == this.id &&
          other.idTransaksi == this.idTransaksi &&
          other.jenis == this.jenis &&
          other.tanggal == this.tanggal &&
          other.jumlahSen == this.jumlahSen &&
          other.kodeMataUang == this.kodeMataUang &&
          other.kategoriId == this.kategoriId &&
          other.catatan == this.catatan &&
          other.sumber == this.sumber &&
          other.tagihanId == this.tagihanId &&
          other.periodeTagihan == this.periodeTagihan &&
          other.dibuatPada == this.dibuatPada &&
          other.diubahPada == this.diubahPada);
}

class TransaksiCompanion extends UpdateCompanion<TransaksiData> {
  final Value<int> id;
  final Value<String> idTransaksi;
  final Value<String> jenis;
  final Value<DateTime> tanggal;
  final Value<int> jumlahSen;
  final Value<String> kodeMataUang;
  final Value<int?> kategoriId;
  final Value<String?> catatan;
  final Value<String> sumber;
  final Value<int?> tagihanId;
  final Value<String?> periodeTagihan;
  final Value<DateTime> dibuatPada;
  final Value<DateTime> diubahPada;
  const TransaksiCompanion({
    this.id = const Value.absent(),
    this.idTransaksi = const Value.absent(),
    this.jenis = const Value.absent(),
    this.tanggal = const Value.absent(),
    this.jumlahSen = const Value.absent(),
    this.kodeMataUang = const Value.absent(),
    this.kategoriId = const Value.absent(),
    this.catatan = const Value.absent(),
    this.sumber = const Value.absent(),
    this.tagihanId = const Value.absent(),
    this.periodeTagihan = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  });
  TransaksiCompanion.insert({
    this.id = const Value.absent(),
    required String idTransaksi,
    this.jenis = const Value.absent(),
    required DateTime tanggal,
    required int jumlahSen,
    this.kodeMataUang = const Value.absent(),
    this.kategoriId = const Value.absent(),
    this.catatan = const Value.absent(),
    this.sumber = const Value.absent(),
    this.tagihanId = const Value.absent(),
    this.periodeTagihan = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  }) : idTransaksi = Value(idTransaksi),
       tanggal = Value(tanggal),
       jumlahSen = Value(jumlahSen);
  static Insertable<TransaksiData> custom({
    Expression<int>? id,
    Expression<String>? idTransaksi,
    Expression<String>? jenis,
    Expression<DateTime>? tanggal,
    Expression<int>? jumlahSen,
    Expression<String>? kodeMataUang,
    Expression<int>? kategoriId,
    Expression<String>? catatan,
    Expression<String>? sumber,
    Expression<int>? tagihanId,
    Expression<String>? periodeTagihan,
    Expression<DateTime>? dibuatPada,
    Expression<DateTime>? diubahPada,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idTransaksi != null) 'id_transaksi': idTransaksi,
      if (jenis != null) 'jenis': jenis,
      if (tanggal != null) 'tanggal': tanggal,
      if (jumlahSen != null) 'jumlah_sen': jumlahSen,
      if (kodeMataUang != null) 'kode_mata_uang': kodeMataUang,
      if (kategoriId != null) 'kategori_id': kategoriId,
      if (catatan != null) 'catatan': catatan,
      if (sumber != null) 'sumber': sumber,
      if (tagihanId != null) 'tagihan_id': tagihanId,
      if (periodeTagihan != null) 'periode_tagihan': periodeTagihan,
      if (dibuatPada != null) 'dibuat_pada': dibuatPada,
      if (diubahPada != null) 'diubah_pada': diubahPada,
    });
  }

  TransaksiCompanion copyWith({
    Value<int>? id,
    Value<String>? idTransaksi,
    Value<String>? jenis,
    Value<DateTime>? tanggal,
    Value<int>? jumlahSen,
    Value<String>? kodeMataUang,
    Value<int?>? kategoriId,
    Value<String?>? catatan,
    Value<String>? sumber,
    Value<int?>? tagihanId,
    Value<String?>? periodeTagihan,
    Value<DateTime>? dibuatPada,
    Value<DateTime>? diubahPada,
  }) {
    return TransaksiCompanion(
      id: id ?? this.id,
      idTransaksi: idTransaksi ?? this.idTransaksi,
      jenis: jenis ?? this.jenis,
      tanggal: tanggal ?? this.tanggal,
      jumlahSen: jumlahSen ?? this.jumlahSen,
      kodeMataUang: kodeMataUang ?? this.kodeMataUang,
      kategoriId: kategoriId ?? this.kategoriId,
      catatan: catatan ?? this.catatan,
      sumber: sumber ?? this.sumber,
      tagihanId: tagihanId ?? this.tagihanId,
      periodeTagihan: periodeTagihan ?? this.periodeTagihan,
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
    if (idTransaksi.present) {
      map['id_transaksi'] = Variable<String>(idTransaksi.value);
    }
    if (jenis.present) {
      map['jenis'] = Variable<String>(jenis.value);
    }
    if (tanggal.present) {
      map['tanggal'] = Variable<DateTime>(tanggal.value);
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
    if (catatan.present) {
      map['catatan'] = Variable<String>(catatan.value);
    }
    if (sumber.present) {
      map['sumber'] = Variable<String>(sumber.value);
    }
    if (tagihanId.present) {
      map['tagihan_id'] = Variable<int>(tagihanId.value);
    }
    if (periodeTagihan.present) {
      map['periode_tagihan'] = Variable<String>(periodeTagihan.value);
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
    return (StringBuffer('TransaksiCompanion(')
          ..write('id: $id, ')
          ..write('idTransaksi: $idTransaksi, ')
          ..write('jenis: $jenis, ')
          ..write('tanggal: $tanggal, ')
          ..write('jumlahSen: $jumlahSen, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('kategoriId: $kategoriId, ')
          ..write('catatan: $catatan, ')
          ..write('sumber: $sumber, ')
          ..write('tagihanId: $tagihanId, ')
          ..write('periodeTagihan: $periodeTagihan, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }
}

class $AnggaranBulananTable extends AnggaranBulanan
    with TableInfo<$AnggaranBulananTable, AnggaranBulananData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnggaranBulananTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _periodeMeta = const VerificationMeta(
    'periode',
  );
  @override
  late final GeneratedColumn<String> periode = GeneratedColumn<String>(
    'periode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kategoriIdMeta = const VerificationMeta(
    'kategoriId',
  );
  @override
  late final GeneratedColumn<int> kategoriId = GeneratedColumn<int>(
    'kategori_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _batasSenMeta = const VerificationMeta(
    'batasSen',
  );
  @override
  late final GeneratedColumn<int> batasSen = GeneratedColumn<int>(
    'batas_sen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ambangPeringatanMeta = const VerificationMeta(
    'ambangPeringatan',
  );
  @override
  late final GeneratedColumn<String> ambangPeringatan = GeneratedColumn<String>(
    'ambang_peringatan',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('80,100'),
  );
  static const VerificationMeta _terkunciMeta = const VerificationMeta(
    'terkunci',
  );
  @override
  late final GeneratedColumn<bool> terkunci = GeneratedColumn<bool>(
    'terkunci',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("terkunci" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dikunciPadaMeta = const VerificationMeta(
    'dikunciPada',
  );
  @override
  late final GeneratedColumn<DateTime> dikunciPada = GeneratedColumn<DateTime>(
    'dikunci_pada',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    periode,
    kategoriId,
    batasSen,
    ambangPeringatan,
    terkunci,
    dikunciPada,
    catatan,
    dibuatPada,
    diubahPada,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'anggaran_bulanan';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnggaranBulananData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('periode')) {
      context.handle(
        _periodeMeta,
        periode.isAcceptableOrUnknown(data['periode']!, _periodeMeta),
      );
    } else if (isInserting) {
      context.missing(_periodeMeta);
    }
    if (data.containsKey('kategori_id')) {
      context.handle(
        _kategoriIdMeta,
        kategoriId.isAcceptableOrUnknown(data['kategori_id']!, _kategoriIdMeta),
      );
    }
    if (data.containsKey('batas_sen')) {
      context.handle(
        _batasSenMeta,
        batasSen.isAcceptableOrUnknown(data['batas_sen']!, _batasSenMeta),
      );
    }
    if (data.containsKey('ambang_peringatan')) {
      context.handle(
        _ambangPeringatanMeta,
        ambangPeringatan.isAcceptableOrUnknown(
          data['ambang_peringatan']!,
          _ambangPeringatanMeta,
        ),
      );
    }
    if (data.containsKey('terkunci')) {
      context.handle(
        _terkunciMeta,
        terkunci.isAcceptableOrUnknown(data['terkunci']!, _terkunciMeta),
      );
    }
    if (data.containsKey('dikunci_pada')) {
      context.handle(
        _dikunciPadaMeta,
        dikunciPada.isAcceptableOrUnknown(
          data['dikunci_pada']!,
          _dikunciPadaMeta,
        ),
      );
    }
    if (data.containsKey('catatan')) {
      context.handle(
        _catatanMeta,
        catatan.isAcceptableOrUnknown(data['catatan']!, _catatanMeta),
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
  AnggaranBulananData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnggaranBulananData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      periode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}periode'],
      )!,
      kategoriId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kategori_id'],
      )!,
      batasSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}batas_sen'],
      )!,
      ambangPeringatan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ambang_peringatan'],
      )!,
      terkunci: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}terkunci'],
      )!,
      dikunciPada: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dikunci_pada'],
      ),
      catatan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catatan'],
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
  $AnggaranBulananTable createAlias(String alias) {
    return $AnggaranBulananTable(attachedDatabase, alias);
  }
}

class AnggaranBulananData extends DataClass
    implements Insertable<AnggaranBulananData> {
  final int id;

  /// 'YYYY-MM'.
  final String periode;

  /// KEPUTUSAN (rancangan §4.3): 0 = anggaran TOTAL bulan itu, selain 0 = id
  /// kategori. Nilai 0 dipakai karena SQLite menganggap NULL berbeda-beda pada
  /// indeks unik — dengan 0 jaminan "satu baris per periode+kategori" tetap
  /// berlaku, dan validitas id diperiksa di repository.
  final int kategoriId;
  final int batasSen;

  /// Ambang peringatan (%), gaya sama seperti `pengingatLeadHari`: "80,100".
  final String ambangPeringatan;
  final bool terkunci;
  final DateTime? dikunciPada;
  final String? catatan;
  final DateTime dibuatPada;
  final DateTime diubahPada;
  const AnggaranBulananData({
    required this.id,
    required this.periode,
    required this.kategoriId,
    required this.batasSen,
    required this.ambangPeringatan,
    required this.terkunci,
    this.dikunciPada,
    this.catatan,
    required this.dibuatPada,
    required this.diubahPada,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['periode'] = Variable<String>(periode);
    map['kategori_id'] = Variable<int>(kategoriId);
    map['batas_sen'] = Variable<int>(batasSen);
    map['ambang_peringatan'] = Variable<String>(ambangPeringatan);
    map['terkunci'] = Variable<bool>(terkunci);
    if (!nullToAbsent || dikunciPada != null) {
      map['dikunci_pada'] = Variable<DateTime>(dikunciPada);
    }
    if (!nullToAbsent || catatan != null) {
      map['catatan'] = Variable<String>(catatan);
    }
    map['dibuat_pada'] = Variable<DateTime>(dibuatPada);
    map['diubah_pada'] = Variable<DateTime>(diubahPada);
    return map;
  }

  AnggaranBulananCompanion toCompanion(bool nullToAbsent) {
    return AnggaranBulananCompanion(
      id: Value(id),
      periode: Value(periode),
      kategoriId: Value(kategoriId),
      batasSen: Value(batasSen),
      ambangPeringatan: Value(ambangPeringatan),
      terkunci: Value(terkunci),
      dikunciPada: dikunciPada == null && nullToAbsent
          ? const Value.absent()
          : Value(dikunciPada),
      catatan: catatan == null && nullToAbsent
          ? const Value.absent()
          : Value(catatan),
      dibuatPada: Value(dibuatPada),
      diubahPada: Value(diubahPada),
    );
  }

  factory AnggaranBulananData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnggaranBulananData(
      id: serializer.fromJson<int>(json['id']),
      periode: serializer.fromJson<String>(json['periode']),
      kategoriId: serializer.fromJson<int>(json['kategoriId']),
      batasSen: serializer.fromJson<int>(json['batasSen']),
      ambangPeringatan: serializer.fromJson<String>(json['ambangPeringatan']),
      terkunci: serializer.fromJson<bool>(json['terkunci']),
      dikunciPada: serializer.fromJson<DateTime?>(json['dikunciPada']),
      catatan: serializer.fromJson<String?>(json['catatan']),
      dibuatPada: serializer.fromJson<DateTime>(json['dibuatPada']),
      diubahPada: serializer.fromJson<DateTime>(json['diubahPada']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'periode': serializer.toJson<String>(periode),
      'kategoriId': serializer.toJson<int>(kategoriId),
      'batasSen': serializer.toJson<int>(batasSen),
      'ambangPeringatan': serializer.toJson<String>(ambangPeringatan),
      'terkunci': serializer.toJson<bool>(terkunci),
      'dikunciPada': serializer.toJson<DateTime?>(dikunciPada),
      'catatan': serializer.toJson<String?>(catatan),
      'dibuatPada': serializer.toJson<DateTime>(dibuatPada),
      'diubahPada': serializer.toJson<DateTime>(diubahPada),
    };
  }

  AnggaranBulananData copyWith({
    int? id,
    String? periode,
    int? kategoriId,
    int? batasSen,
    String? ambangPeringatan,
    bool? terkunci,
    Value<DateTime?> dikunciPada = const Value.absent(),
    Value<String?> catatan = const Value.absent(),
    DateTime? dibuatPada,
    DateTime? diubahPada,
  }) => AnggaranBulananData(
    id: id ?? this.id,
    periode: periode ?? this.periode,
    kategoriId: kategoriId ?? this.kategoriId,
    batasSen: batasSen ?? this.batasSen,
    ambangPeringatan: ambangPeringatan ?? this.ambangPeringatan,
    terkunci: terkunci ?? this.terkunci,
    dikunciPada: dikunciPada.present ? dikunciPada.value : this.dikunciPada,
    catatan: catatan.present ? catatan.value : this.catatan,
    dibuatPada: dibuatPada ?? this.dibuatPada,
    diubahPada: diubahPada ?? this.diubahPada,
  );
  AnggaranBulananData copyWithCompanion(AnggaranBulananCompanion data) {
    return AnggaranBulananData(
      id: data.id.present ? data.id.value : this.id,
      periode: data.periode.present ? data.periode.value : this.periode,
      kategoriId: data.kategoriId.present
          ? data.kategoriId.value
          : this.kategoriId,
      batasSen: data.batasSen.present ? data.batasSen.value : this.batasSen,
      ambangPeringatan: data.ambangPeringatan.present
          ? data.ambangPeringatan.value
          : this.ambangPeringatan,
      terkunci: data.terkunci.present ? data.terkunci.value : this.terkunci,
      dikunciPada: data.dikunciPada.present
          ? data.dikunciPada.value
          : this.dikunciPada,
      catatan: data.catatan.present ? data.catatan.value : this.catatan,
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
    return (StringBuffer('AnggaranBulananData(')
          ..write('id: $id, ')
          ..write('periode: $periode, ')
          ..write('kategoriId: $kategoriId, ')
          ..write('batasSen: $batasSen, ')
          ..write('ambangPeringatan: $ambangPeringatan, ')
          ..write('terkunci: $terkunci, ')
          ..write('dikunciPada: $dikunciPada, ')
          ..write('catatan: $catatan, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    periode,
    kategoriId,
    batasSen,
    ambangPeringatan,
    terkunci,
    dikunciPada,
    catatan,
    dibuatPada,
    diubahPada,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnggaranBulananData &&
          other.id == this.id &&
          other.periode == this.periode &&
          other.kategoriId == this.kategoriId &&
          other.batasSen == this.batasSen &&
          other.ambangPeringatan == this.ambangPeringatan &&
          other.terkunci == this.terkunci &&
          other.dikunciPada == this.dikunciPada &&
          other.catatan == this.catatan &&
          other.dibuatPada == this.dibuatPada &&
          other.diubahPada == this.diubahPada);
}

class AnggaranBulananCompanion extends UpdateCompanion<AnggaranBulananData> {
  final Value<int> id;
  final Value<String> periode;
  final Value<int> kategoriId;
  final Value<int> batasSen;
  final Value<String> ambangPeringatan;
  final Value<bool> terkunci;
  final Value<DateTime?> dikunciPada;
  final Value<String?> catatan;
  final Value<DateTime> dibuatPada;
  final Value<DateTime> diubahPada;
  const AnggaranBulananCompanion({
    this.id = const Value.absent(),
    this.periode = const Value.absent(),
    this.kategoriId = const Value.absent(),
    this.batasSen = const Value.absent(),
    this.ambangPeringatan = const Value.absent(),
    this.terkunci = const Value.absent(),
    this.dikunciPada = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  });
  AnggaranBulananCompanion.insert({
    this.id = const Value.absent(),
    required String periode,
    this.kategoriId = const Value.absent(),
    this.batasSen = const Value.absent(),
    this.ambangPeringatan = const Value.absent(),
    this.terkunci = const Value.absent(),
    this.dikunciPada = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  }) : periode = Value(periode);
  static Insertable<AnggaranBulananData> custom({
    Expression<int>? id,
    Expression<String>? periode,
    Expression<int>? kategoriId,
    Expression<int>? batasSen,
    Expression<String>? ambangPeringatan,
    Expression<bool>? terkunci,
    Expression<DateTime>? dikunciPada,
    Expression<String>? catatan,
    Expression<DateTime>? dibuatPada,
    Expression<DateTime>? diubahPada,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (periode != null) 'periode': periode,
      if (kategoriId != null) 'kategori_id': kategoriId,
      if (batasSen != null) 'batas_sen': batasSen,
      if (ambangPeringatan != null) 'ambang_peringatan': ambangPeringatan,
      if (terkunci != null) 'terkunci': terkunci,
      if (dikunciPada != null) 'dikunci_pada': dikunciPada,
      if (catatan != null) 'catatan': catatan,
      if (dibuatPada != null) 'dibuat_pada': dibuatPada,
      if (diubahPada != null) 'diubah_pada': diubahPada,
    });
  }

  AnggaranBulananCompanion copyWith({
    Value<int>? id,
    Value<String>? periode,
    Value<int>? kategoriId,
    Value<int>? batasSen,
    Value<String>? ambangPeringatan,
    Value<bool>? terkunci,
    Value<DateTime?>? dikunciPada,
    Value<String?>? catatan,
    Value<DateTime>? dibuatPada,
    Value<DateTime>? diubahPada,
  }) {
    return AnggaranBulananCompanion(
      id: id ?? this.id,
      periode: periode ?? this.periode,
      kategoriId: kategoriId ?? this.kategoriId,
      batasSen: batasSen ?? this.batasSen,
      ambangPeringatan: ambangPeringatan ?? this.ambangPeringatan,
      terkunci: terkunci ?? this.terkunci,
      dikunciPada: dikunciPada ?? this.dikunciPada,
      catatan: catatan ?? this.catatan,
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
    if (periode.present) {
      map['periode'] = Variable<String>(periode.value);
    }
    if (kategoriId.present) {
      map['kategori_id'] = Variable<int>(kategoriId.value);
    }
    if (batasSen.present) {
      map['batas_sen'] = Variable<int>(batasSen.value);
    }
    if (ambangPeringatan.present) {
      map['ambang_peringatan'] = Variable<String>(ambangPeringatan.value);
    }
    if (terkunci.present) {
      map['terkunci'] = Variable<bool>(terkunci.value);
    }
    if (dikunciPada.present) {
      map['dikunci_pada'] = Variable<DateTime>(dikunciPada.value);
    }
    if (catatan.present) {
      map['catatan'] = Variable<String>(catatan.value);
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
    return (StringBuffer('AnggaranBulananCompanion(')
          ..write('id: $id, ')
          ..write('periode: $periode, ')
          ..write('kategoriId: $kategoriId, ')
          ..write('batasSen: $batasSen, ')
          ..write('ambangPeringatan: $ambangPeringatan, ')
          ..write('terkunci: $terkunci, ')
          ..write('dikunciPada: $dikunciPada, ')
          ..write('catatan: $catatan, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }
}

class $LanggananTable extends Langganan
    with TableInfo<$LanggananTable, LanggananData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LanggananTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _idLanggananMeta = const VerificationMeta(
    'idLangganan',
  );
  @override
  late final GeneratedColumn<String> idLangganan = GeneratedColumn<String>(
    'id_langganan',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagihanIdMeta = const VerificationMeta(
    'tagihanId',
  );
  @override
  late final GeneratedColumn<int> tagihanId = GeneratedColumn<int>(
    'tagihan_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tagihan (id)',
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
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nominalSenMeta = const VerificationMeta(
    'nominalSen',
  );
  @override
  late final GeneratedColumn<int> nominalSen = GeneratedColumn<int>(
    'nominal_sen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
      'REFERENCES kategori_transaksi (id)',
    ),
  );
  static const VerificationMeta _siklusMeta = const VerificationMeta('siklus');
  @override
  late final GeneratedColumn<String> siklus = GeneratedColumn<String>(
    'siklus',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('bulanan'),
  );
  static const VerificationMeta _tanggalMulaiMeta = const VerificationMeta(
    'tanggalMulai',
  );
  @override
  late final GeneratedColumn<DateTime> tanggalMulai = GeneratedColumn<DateTime>(
    'tanggal_mulai',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _perpanjangOtomatisMeta =
      const VerificationMeta('perpanjangOtomatis');
  @override
  late final GeneratedColumn<bool> perpanjangOtomatis = GeneratedColumn<bool>(
    'perpanjang_otomatis',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("perpanjang_otomatis" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('aktif'),
  );
  static const VerificationMeta _pauseSejakMeta = const VerificationMeta(
    'pauseSejak',
  );
  @override
  late final GeneratedColumn<DateTime> pauseSejak = GeneratedColumn<DateTime>(
    'pause_sejak',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pauseSampaiMeta = const VerificationMeta(
    'pauseSampai',
  );
  @override
  late final GeneratedColumn<DateTime> pauseSampai = GeneratedColumn<DateTime>(
    'pause_sampai',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metodeBayarMeta = const VerificationMeta(
    'metodeBayar',
  );
  @override
  late final GeneratedColumn<String> metodeBayar = GeneratedColumn<String>(
    'metode_bayar',
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
  static const VerificationMeta _terakhirDipakaiPadaMeta =
      const VerificationMeta('terakhirDipakaiPada');
  @override
  late final GeneratedColumn<DateTime> terakhirDipakaiPada =
      GeneratedColumn<DateTime>(
        'terakhir_dipakai_pada',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
    idLangganan,
    tagihanId,
    nama,
    nominalSen,
    kodeMataUang,
    kategoriId,
    siklus,
    tanggalMulai,
    perpanjangOtomatis,
    status,
    pauseSejak,
    pauseSampai,
    metodeBayar,
    tautanBayar,
    terakhirDipakaiPada,
    catatan,
    dibuatPada,
    diubahPada,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'langganan';
  @override
  VerificationContext validateIntegrity(
    Insertable<LanggananData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('id_langganan')) {
      context.handle(
        _idLanggananMeta,
        idLangganan.isAcceptableOrUnknown(
          data['id_langganan']!,
          _idLanggananMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idLanggananMeta);
    }
    if (data.containsKey('tagihan_id')) {
      context.handle(
        _tagihanIdMeta,
        tagihanId.isAcceptableOrUnknown(data['tagihan_id']!, _tagihanIdMeta),
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
    if (data.containsKey('nominal_sen')) {
      context.handle(
        _nominalSenMeta,
        nominalSen.isAcceptableOrUnknown(data['nominal_sen']!, _nominalSenMeta),
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
    if (data.containsKey('siklus')) {
      context.handle(
        _siklusMeta,
        siklus.isAcceptableOrUnknown(data['siklus']!, _siklusMeta),
      );
    }
    if (data.containsKey('tanggal_mulai')) {
      context.handle(
        _tanggalMulaiMeta,
        tanggalMulai.isAcceptableOrUnknown(
          data['tanggal_mulai']!,
          _tanggalMulaiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tanggalMulaiMeta);
    }
    if (data.containsKey('perpanjang_otomatis')) {
      context.handle(
        _perpanjangOtomatisMeta,
        perpanjangOtomatis.isAcceptableOrUnknown(
          data['perpanjang_otomatis']!,
          _perpanjangOtomatisMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('pause_sejak')) {
      context.handle(
        _pauseSejakMeta,
        pauseSejak.isAcceptableOrUnknown(data['pause_sejak']!, _pauseSejakMeta),
      );
    }
    if (data.containsKey('pause_sampai')) {
      context.handle(
        _pauseSampaiMeta,
        pauseSampai.isAcceptableOrUnknown(
          data['pause_sampai']!,
          _pauseSampaiMeta,
        ),
      );
    }
    if (data.containsKey('metode_bayar')) {
      context.handle(
        _metodeBayarMeta,
        metodeBayar.isAcceptableOrUnknown(
          data['metode_bayar']!,
          _metodeBayarMeta,
        ),
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
    if (data.containsKey('terakhir_dipakai_pada')) {
      context.handle(
        _terakhirDipakaiPadaMeta,
        terakhirDipakaiPada.isAcceptableOrUnknown(
          data['terakhir_dipakai_pada']!,
          _terakhirDipakaiPadaMeta,
        ),
      );
    }
    if (data.containsKey('catatan')) {
      context.handle(
        _catatanMeta,
        catatan.isAcceptableOrUnknown(data['catatan']!, _catatanMeta),
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
  LanggananData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LanggananData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      idLangganan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id_langganan'],
      )!,
      tagihanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tagihan_id'],
      ),
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      nominalSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nominal_sen'],
      )!,
      kodeMataUang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kode_mata_uang'],
      )!,
      kategoriId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kategori_id'],
      ),
      siklus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}siklus'],
      )!,
      tanggalMulai: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tanggal_mulai'],
      )!,
      perpanjangOtomatis: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}perpanjang_otomatis'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      pauseSejak: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pause_sejak'],
      ),
      pauseSampai: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pause_sampai'],
      ),
      metodeBayar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metode_bayar'],
      ),
      tautanBayar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tautan_bayar'],
      ),
      terakhirDipakaiPada: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}terakhir_dipakai_pada'],
      ),
      catatan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catatan'],
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
  $LanggananTable createAlias(String alias) {
    return $LanggananTable(attachedDatabase, alias);
  }
}

class LanggananData extends DataClass implements Insertable<LanggananData> {
  final int id;

  /// Unik. Pengenal stabil (`lgn_<microseconds>`), dipakai sebagai bagian
  /// payload notifikasi + kunci impor/ekspor.
  final String idLangganan;

  /// Tagihan tertaut (opsional). Satu tagihan dipakai paling banyak satu
  /// langganan (indeks unik parsial di `database.dart`).
  final int? tagihanId;
  final String nama;
  final int nominalSen;
  final String kodeMataUang;
  final int? kategoriId;

  /// Nilai Frekuensi.nilaiDb: bulanan, tahunan, mingguan, …
  final String siklus;
  final DateTime tanggalMulai;
  final bool perpanjangOtomatis;

  /// `aktif` / `pause` / `berhenti` (StatusLangganan).
  final String status;
  final DateTime? pauseSejak;
  final DateTime? pauseSampai;
  final String? metodeBayar;
  final String? tautanBayar;
  final DateTime? terakhirDipakaiPada;
  final String? catatan;
  final DateTime dibuatPada;
  final DateTime diubahPada;
  const LanggananData({
    required this.id,
    required this.idLangganan,
    this.tagihanId,
    required this.nama,
    required this.nominalSen,
    required this.kodeMataUang,
    this.kategoriId,
    required this.siklus,
    required this.tanggalMulai,
    required this.perpanjangOtomatis,
    required this.status,
    this.pauseSejak,
    this.pauseSampai,
    this.metodeBayar,
    this.tautanBayar,
    this.terakhirDipakaiPada,
    this.catatan,
    required this.dibuatPada,
    required this.diubahPada,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['id_langganan'] = Variable<String>(idLangganan);
    if (!nullToAbsent || tagihanId != null) {
      map['tagihan_id'] = Variable<int>(tagihanId);
    }
    map['nama'] = Variable<String>(nama);
    map['nominal_sen'] = Variable<int>(nominalSen);
    map['kode_mata_uang'] = Variable<String>(kodeMataUang);
    if (!nullToAbsent || kategoriId != null) {
      map['kategori_id'] = Variable<int>(kategoriId);
    }
    map['siklus'] = Variable<String>(siklus);
    map['tanggal_mulai'] = Variable<DateTime>(tanggalMulai);
    map['perpanjang_otomatis'] = Variable<bool>(perpanjangOtomatis);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || pauseSejak != null) {
      map['pause_sejak'] = Variable<DateTime>(pauseSejak);
    }
    if (!nullToAbsent || pauseSampai != null) {
      map['pause_sampai'] = Variable<DateTime>(pauseSampai);
    }
    if (!nullToAbsent || metodeBayar != null) {
      map['metode_bayar'] = Variable<String>(metodeBayar);
    }
    if (!nullToAbsent || tautanBayar != null) {
      map['tautan_bayar'] = Variable<String>(tautanBayar);
    }
    if (!nullToAbsent || terakhirDipakaiPada != null) {
      map['terakhir_dipakai_pada'] = Variable<DateTime>(terakhirDipakaiPada);
    }
    if (!nullToAbsent || catatan != null) {
      map['catatan'] = Variable<String>(catatan);
    }
    map['dibuat_pada'] = Variable<DateTime>(dibuatPada);
    map['diubah_pada'] = Variable<DateTime>(diubahPada);
    return map;
  }

  LanggananCompanion toCompanion(bool nullToAbsent) {
    return LanggananCompanion(
      id: Value(id),
      idLangganan: Value(idLangganan),
      tagihanId: tagihanId == null && nullToAbsent
          ? const Value.absent()
          : Value(tagihanId),
      nama: Value(nama),
      nominalSen: Value(nominalSen),
      kodeMataUang: Value(kodeMataUang),
      kategoriId: kategoriId == null && nullToAbsent
          ? const Value.absent()
          : Value(kategoriId),
      siklus: Value(siklus),
      tanggalMulai: Value(tanggalMulai),
      perpanjangOtomatis: Value(perpanjangOtomatis),
      status: Value(status),
      pauseSejak: pauseSejak == null && nullToAbsent
          ? const Value.absent()
          : Value(pauseSejak),
      pauseSampai: pauseSampai == null && nullToAbsent
          ? const Value.absent()
          : Value(pauseSampai),
      metodeBayar: metodeBayar == null && nullToAbsent
          ? const Value.absent()
          : Value(metodeBayar),
      tautanBayar: tautanBayar == null && nullToAbsent
          ? const Value.absent()
          : Value(tautanBayar),
      terakhirDipakaiPada: terakhirDipakaiPada == null && nullToAbsent
          ? const Value.absent()
          : Value(terakhirDipakaiPada),
      catatan: catatan == null && nullToAbsent
          ? const Value.absent()
          : Value(catatan),
      dibuatPada: Value(dibuatPada),
      diubahPada: Value(diubahPada),
    );
  }

  factory LanggananData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LanggananData(
      id: serializer.fromJson<int>(json['id']),
      idLangganan: serializer.fromJson<String>(json['idLangganan']),
      tagihanId: serializer.fromJson<int?>(json['tagihanId']),
      nama: serializer.fromJson<String>(json['nama']),
      nominalSen: serializer.fromJson<int>(json['nominalSen']),
      kodeMataUang: serializer.fromJson<String>(json['kodeMataUang']),
      kategoriId: serializer.fromJson<int?>(json['kategoriId']),
      siklus: serializer.fromJson<String>(json['siklus']),
      tanggalMulai: serializer.fromJson<DateTime>(json['tanggalMulai']),
      perpanjangOtomatis: serializer.fromJson<bool>(json['perpanjangOtomatis']),
      status: serializer.fromJson<String>(json['status']),
      pauseSejak: serializer.fromJson<DateTime?>(json['pauseSejak']),
      pauseSampai: serializer.fromJson<DateTime?>(json['pauseSampai']),
      metodeBayar: serializer.fromJson<String?>(json['metodeBayar']),
      tautanBayar: serializer.fromJson<String?>(json['tautanBayar']),
      terakhirDipakaiPada: serializer.fromJson<DateTime?>(
        json['terakhirDipakaiPada'],
      ),
      catatan: serializer.fromJson<String?>(json['catatan']),
      dibuatPada: serializer.fromJson<DateTime>(json['dibuatPada']),
      diubahPada: serializer.fromJson<DateTime>(json['diubahPada']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'idLangganan': serializer.toJson<String>(idLangganan),
      'tagihanId': serializer.toJson<int?>(tagihanId),
      'nama': serializer.toJson<String>(nama),
      'nominalSen': serializer.toJson<int>(nominalSen),
      'kodeMataUang': serializer.toJson<String>(kodeMataUang),
      'kategoriId': serializer.toJson<int?>(kategoriId),
      'siklus': serializer.toJson<String>(siklus),
      'tanggalMulai': serializer.toJson<DateTime>(tanggalMulai),
      'perpanjangOtomatis': serializer.toJson<bool>(perpanjangOtomatis),
      'status': serializer.toJson<String>(status),
      'pauseSejak': serializer.toJson<DateTime?>(pauseSejak),
      'pauseSampai': serializer.toJson<DateTime?>(pauseSampai),
      'metodeBayar': serializer.toJson<String?>(metodeBayar),
      'tautanBayar': serializer.toJson<String?>(tautanBayar),
      'terakhirDipakaiPada': serializer.toJson<DateTime?>(terakhirDipakaiPada),
      'catatan': serializer.toJson<String?>(catatan),
      'dibuatPada': serializer.toJson<DateTime>(dibuatPada),
      'diubahPada': serializer.toJson<DateTime>(diubahPada),
    };
  }

  LanggananData copyWith({
    int? id,
    String? idLangganan,
    Value<int?> tagihanId = const Value.absent(),
    String? nama,
    int? nominalSen,
    String? kodeMataUang,
    Value<int?> kategoriId = const Value.absent(),
    String? siklus,
    DateTime? tanggalMulai,
    bool? perpanjangOtomatis,
    String? status,
    Value<DateTime?> pauseSejak = const Value.absent(),
    Value<DateTime?> pauseSampai = const Value.absent(),
    Value<String?> metodeBayar = const Value.absent(),
    Value<String?> tautanBayar = const Value.absent(),
    Value<DateTime?> terakhirDipakaiPada = const Value.absent(),
    Value<String?> catatan = const Value.absent(),
    DateTime? dibuatPada,
    DateTime? diubahPada,
  }) => LanggananData(
    id: id ?? this.id,
    idLangganan: idLangganan ?? this.idLangganan,
    tagihanId: tagihanId.present ? tagihanId.value : this.tagihanId,
    nama: nama ?? this.nama,
    nominalSen: nominalSen ?? this.nominalSen,
    kodeMataUang: kodeMataUang ?? this.kodeMataUang,
    kategoriId: kategoriId.present ? kategoriId.value : this.kategoriId,
    siklus: siklus ?? this.siklus,
    tanggalMulai: tanggalMulai ?? this.tanggalMulai,
    perpanjangOtomatis: perpanjangOtomatis ?? this.perpanjangOtomatis,
    status: status ?? this.status,
    pauseSejak: pauseSejak.present ? pauseSejak.value : this.pauseSejak,
    pauseSampai: pauseSampai.present ? pauseSampai.value : this.pauseSampai,
    metodeBayar: metodeBayar.present ? metodeBayar.value : this.metodeBayar,
    tautanBayar: tautanBayar.present ? tautanBayar.value : this.tautanBayar,
    terakhirDipakaiPada: terakhirDipakaiPada.present
        ? terakhirDipakaiPada.value
        : this.terakhirDipakaiPada,
    catatan: catatan.present ? catatan.value : this.catatan,
    dibuatPada: dibuatPada ?? this.dibuatPada,
    diubahPada: diubahPada ?? this.diubahPada,
  );
  LanggananData copyWithCompanion(LanggananCompanion data) {
    return LanggananData(
      id: data.id.present ? data.id.value : this.id,
      idLangganan: data.idLangganan.present
          ? data.idLangganan.value
          : this.idLangganan,
      tagihanId: data.tagihanId.present ? data.tagihanId.value : this.tagihanId,
      nama: data.nama.present ? data.nama.value : this.nama,
      nominalSen: data.nominalSen.present
          ? data.nominalSen.value
          : this.nominalSen,
      kodeMataUang: data.kodeMataUang.present
          ? data.kodeMataUang.value
          : this.kodeMataUang,
      kategoriId: data.kategoriId.present
          ? data.kategoriId.value
          : this.kategoriId,
      siklus: data.siklus.present ? data.siklus.value : this.siklus,
      tanggalMulai: data.tanggalMulai.present
          ? data.tanggalMulai.value
          : this.tanggalMulai,
      perpanjangOtomatis: data.perpanjangOtomatis.present
          ? data.perpanjangOtomatis.value
          : this.perpanjangOtomatis,
      status: data.status.present ? data.status.value : this.status,
      pauseSejak: data.pauseSejak.present
          ? data.pauseSejak.value
          : this.pauseSejak,
      pauseSampai: data.pauseSampai.present
          ? data.pauseSampai.value
          : this.pauseSampai,
      metodeBayar: data.metodeBayar.present
          ? data.metodeBayar.value
          : this.metodeBayar,
      tautanBayar: data.tautanBayar.present
          ? data.tautanBayar.value
          : this.tautanBayar,
      terakhirDipakaiPada: data.terakhirDipakaiPada.present
          ? data.terakhirDipakaiPada.value
          : this.terakhirDipakaiPada,
      catatan: data.catatan.present ? data.catatan.value : this.catatan,
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
    return (StringBuffer('LanggananData(')
          ..write('id: $id, ')
          ..write('idLangganan: $idLangganan, ')
          ..write('tagihanId: $tagihanId, ')
          ..write('nama: $nama, ')
          ..write('nominalSen: $nominalSen, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('kategoriId: $kategoriId, ')
          ..write('siklus: $siklus, ')
          ..write('tanggalMulai: $tanggalMulai, ')
          ..write('perpanjangOtomatis: $perpanjangOtomatis, ')
          ..write('status: $status, ')
          ..write('pauseSejak: $pauseSejak, ')
          ..write('pauseSampai: $pauseSampai, ')
          ..write('metodeBayar: $metodeBayar, ')
          ..write('tautanBayar: $tautanBayar, ')
          ..write('terakhirDipakaiPada: $terakhirDipakaiPada, ')
          ..write('catatan: $catatan, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    idLangganan,
    tagihanId,
    nama,
    nominalSen,
    kodeMataUang,
    kategoriId,
    siklus,
    tanggalMulai,
    perpanjangOtomatis,
    status,
    pauseSejak,
    pauseSampai,
    metodeBayar,
    tautanBayar,
    terakhirDipakaiPada,
    catatan,
    dibuatPada,
    diubahPada,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LanggananData &&
          other.id == this.id &&
          other.idLangganan == this.idLangganan &&
          other.tagihanId == this.tagihanId &&
          other.nama == this.nama &&
          other.nominalSen == this.nominalSen &&
          other.kodeMataUang == this.kodeMataUang &&
          other.kategoriId == this.kategoriId &&
          other.siklus == this.siklus &&
          other.tanggalMulai == this.tanggalMulai &&
          other.perpanjangOtomatis == this.perpanjangOtomatis &&
          other.status == this.status &&
          other.pauseSejak == this.pauseSejak &&
          other.pauseSampai == this.pauseSampai &&
          other.metodeBayar == this.metodeBayar &&
          other.tautanBayar == this.tautanBayar &&
          other.terakhirDipakaiPada == this.terakhirDipakaiPada &&
          other.catatan == this.catatan &&
          other.dibuatPada == this.dibuatPada &&
          other.diubahPada == this.diubahPada);
}

class LanggananCompanion extends UpdateCompanion<LanggananData> {
  final Value<int> id;
  final Value<String> idLangganan;
  final Value<int?> tagihanId;
  final Value<String> nama;
  final Value<int> nominalSen;
  final Value<String> kodeMataUang;
  final Value<int?> kategoriId;
  final Value<String> siklus;
  final Value<DateTime> tanggalMulai;
  final Value<bool> perpanjangOtomatis;
  final Value<String> status;
  final Value<DateTime?> pauseSejak;
  final Value<DateTime?> pauseSampai;
  final Value<String?> metodeBayar;
  final Value<String?> tautanBayar;
  final Value<DateTime?> terakhirDipakaiPada;
  final Value<String?> catatan;
  final Value<DateTime> dibuatPada;
  final Value<DateTime> diubahPada;
  const LanggananCompanion({
    this.id = const Value.absent(),
    this.idLangganan = const Value.absent(),
    this.tagihanId = const Value.absent(),
    this.nama = const Value.absent(),
    this.nominalSen = const Value.absent(),
    this.kodeMataUang = const Value.absent(),
    this.kategoriId = const Value.absent(),
    this.siklus = const Value.absent(),
    this.tanggalMulai = const Value.absent(),
    this.perpanjangOtomatis = const Value.absent(),
    this.status = const Value.absent(),
    this.pauseSejak = const Value.absent(),
    this.pauseSampai = const Value.absent(),
    this.metodeBayar = const Value.absent(),
    this.tautanBayar = const Value.absent(),
    this.terakhirDipakaiPada = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  });
  LanggananCompanion.insert({
    this.id = const Value.absent(),
    required String idLangganan,
    this.tagihanId = const Value.absent(),
    required String nama,
    this.nominalSen = const Value.absent(),
    this.kodeMataUang = const Value.absent(),
    this.kategoriId = const Value.absent(),
    this.siklus = const Value.absent(),
    required DateTime tanggalMulai,
    this.perpanjangOtomatis = const Value.absent(),
    this.status = const Value.absent(),
    this.pauseSejak = const Value.absent(),
    this.pauseSampai = const Value.absent(),
    this.metodeBayar = const Value.absent(),
    this.tautanBayar = const Value.absent(),
    this.terakhirDipakaiPada = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  }) : idLangganan = Value(idLangganan),
       nama = Value(nama),
       tanggalMulai = Value(tanggalMulai);
  static Insertable<LanggananData> custom({
    Expression<int>? id,
    Expression<String>? idLangganan,
    Expression<int>? tagihanId,
    Expression<String>? nama,
    Expression<int>? nominalSen,
    Expression<String>? kodeMataUang,
    Expression<int>? kategoriId,
    Expression<String>? siklus,
    Expression<DateTime>? tanggalMulai,
    Expression<bool>? perpanjangOtomatis,
    Expression<String>? status,
    Expression<DateTime>? pauseSejak,
    Expression<DateTime>? pauseSampai,
    Expression<String>? metodeBayar,
    Expression<String>? tautanBayar,
    Expression<DateTime>? terakhirDipakaiPada,
    Expression<String>? catatan,
    Expression<DateTime>? dibuatPada,
    Expression<DateTime>? diubahPada,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idLangganan != null) 'id_langganan': idLangganan,
      if (tagihanId != null) 'tagihan_id': tagihanId,
      if (nama != null) 'nama': nama,
      if (nominalSen != null) 'nominal_sen': nominalSen,
      if (kodeMataUang != null) 'kode_mata_uang': kodeMataUang,
      if (kategoriId != null) 'kategori_id': kategoriId,
      if (siklus != null) 'siklus': siklus,
      if (tanggalMulai != null) 'tanggal_mulai': tanggalMulai,
      if (perpanjangOtomatis != null) 'perpanjang_otomatis': perpanjangOtomatis,
      if (status != null) 'status': status,
      if (pauseSejak != null) 'pause_sejak': pauseSejak,
      if (pauseSampai != null) 'pause_sampai': pauseSampai,
      if (metodeBayar != null) 'metode_bayar': metodeBayar,
      if (tautanBayar != null) 'tautan_bayar': tautanBayar,
      if (terakhirDipakaiPada != null)
        'terakhir_dipakai_pada': terakhirDipakaiPada,
      if (catatan != null) 'catatan': catatan,
      if (dibuatPada != null) 'dibuat_pada': dibuatPada,
      if (diubahPada != null) 'diubah_pada': diubahPada,
    });
  }

  LanggananCompanion copyWith({
    Value<int>? id,
    Value<String>? idLangganan,
    Value<int?>? tagihanId,
    Value<String>? nama,
    Value<int>? nominalSen,
    Value<String>? kodeMataUang,
    Value<int?>? kategoriId,
    Value<String>? siklus,
    Value<DateTime>? tanggalMulai,
    Value<bool>? perpanjangOtomatis,
    Value<String>? status,
    Value<DateTime?>? pauseSejak,
    Value<DateTime?>? pauseSampai,
    Value<String?>? metodeBayar,
    Value<String?>? tautanBayar,
    Value<DateTime?>? terakhirDipakaiPada,
    Value<String?>? catatan,
    Value<DateTime>? dibuatPada,
    Value<DateTime>? diubahPada,
  }) {
    return LanggananCompanion(
      id: id ?? this.id,
      idLangganan: idLangganan ?? this.idLangganan,
      tagihanId: tagihanId ?? this.tagihanId,
      nama: nama ?? this.nama,
      nominalSen: nominalSen ?? this.nominalSen,
      kodeMataUang: kodeMataUang ?? this.kodeMataUang,
      kategoriId: kategoriId ?? this.kategoriId,
      siklus: siklus ?? this.siklus,
      tanggalMulai: tanggalMulai ?? this.tanggalMulai,
      perpanjangOtomatis: perpanjangOtomatis ?? this.perpanjangOtomatis,
      status: status ?? this.status,
      pauseSejak: pauseSejak ?? this.pauseSejak,
      pauseSampai: pauseSampai ?? this.pauseSampai,
      metodeBayar: metodeBayar ?? this.metodeBayar,
      tautanBayar: tautanBayar ?? this.tautanBayar,
      terakhirDipakaiPada: terakhirDipakaiPada ?? this.terakhirDipakaiPada,
      catatan: catatan ?? this.catatan,
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
    if (idLangganan.present) {
      map['id_langganan'] = Variable<String>(idLangganan.value);
    }
    if (tagihanId.present) {
      map['tagihan_id'] = Variable<int>(tagihanId.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (nominalSen.present) {
      map['nominal_sen'] = Variable<int>(nominalSen.value);
    }
    if (kodeMataUang.present) {
      map['kode_mata_uang'] = Variable<String>(kodeMataUang.value);
    }
    if (kategoriId.present) {
      map['kategori_id'] = Variable<int>(kategoriId.value);
    }
    if (siklus.present) {
      map['siklus'] = Variable<String>(siklus.value);
    }
    if (tanggalMulai.present) {
      map['tanggal_mulai'] = Variable<DateTime>(tanggalMulai.value);
    }
    if (perpanjangOtomatis.present) {
      map['perpanjang_otomatis'] = Variable<bool>(perpanjangOtomatis.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (pauseSejak.present) {
      map['pause_sejak'] = Variable<DateTime>(pauseSejak.value);
    }
    if (pauseSampai.present) {
      map['pause_sampai'] = Variable<DateTime>(pauseSampai.value);
    }
    if (metodeBayar.present) {
      map['metode_bayar'] = Variable<String>(metodeBayar.value);
    }
    if (tautanBayar.present) {
      map['tautan_bayar'] = Variable<String>(tautanBayar.value);
    }
    if (terakhirDipakaiPada.present) {
      map['terakhir_dipakai_pada'] = Variable<DateTime>(
        terakhirDipakaiPada.value,
      );
    }
    if (catatan.present) {
      map['catatan'] = Variable<String>(catatan.value);
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
    return (StringBuffer('LanggananCompanion(')
          ..write('id: $id, ')
          ..write('idLangganan: $idLangganan, ')
          ..write('tagihanId: $tagihanId, ')
          ..write('nama: $nama, ')
          ..write('nominalSen: $nominalSen, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('kategoriId: $kategoriId, ')
          ..write('siklus: $siklus, ')
          ..write('tanggalMulai: $tanggalMulai, ')
          ..write('perpanjangOtomatis: $perpanjangOtomatis, ')
          ..write('status: $status, ')
          ..write('pauseSejak: $pauseSejak, ')
          ..write('pauseSampai: $pauseSampai, ')
          ..write('metodeBayar: $metodeBayar, ')
          ..write('tautanBayar: $tautanBayar, ')
          ..write('terakhirDipakaiPada: $terakhirDipakaiPada, ')
          ..write('catatan: $catatan, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }
}

class $AsetTable extends Aset with TableInfo<$AsetTable, AsetData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AsetTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _idAsetMeta = const VerificationMeta('idAset');
  @override
  late final GeneratedColumn<String> idAset = GeneratedColumn<String>(
    'id_aset',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _jenisMeta = const VerificationMeta('jenis');
  @override
  late final GeneratedColumn<String> jenis = GeneratedColumn<String>(
    'jenis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('kas'),
  );
  static const VerificationMeta _institusiMeta = const VerificationMeta(
    'institusi',
  );
  @override
  late final GeneratedColumn<String> institusi = GeneratedColumn<String>(
    'institusi',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _nilaiAwalSenMeta = const VerificationMeta(
    'nilaiAwalSen',
  );
  @override
  late final GeneratedColumn<int> nilaiAwalSen = GeneratedColumn<int>(
    'nilai_awal_sen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _likuidMeta = const VerificationMeta('likuid');
  @override
  late final GeneratedColumn<bool> likuid = GeneratedColumn<bool>(
    'likuid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("likuid" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _arsipMeta = const VerificationMeta('arsip');
  @override
  late final GeneratedColumn<bool> arsip = GeneratedColumn<bool>(
    'arsip',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("arsip" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    idAset,
    nama,
    jenis,
    institusi,
    kodeMataUang,
    nilaiAwalSen,
    likuid,
    arsip,
    catatan,
    dibuatPada,
    diubahPada,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'aset';
  @override
  VerificationContext validateIntegrity(
    Insertable<AsetData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('id_aset')) {
      context.handle(
        _idAsetMeta,
        idAset.isAcceptableOrUnknown(data['id_aset']!, _idAsetMeta),
      );
    } else if (isInserting) {
      context.missing(_idAsetMeta);
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('jenis')) {
      context.handle(
        _jenisMeta,
        jenis.isAcceptableOrUnknown(data['jenis']!, _jenisMeta),
      );
    }
    if (data.containsKey('institusi')) {
      context.handle(
        _institusiMeta,
        institusi.isAcceptableOrUnknown(data['institusi']!, _institusiMeta),
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
    if (data.containsKey('nilai_awal_sen')) {
      context.handle(
        _nilaiAwalSenMeta,
        nilaiAwalSen.isAcceptableOrUnknown(
          data['nilai_awal_sen']!,
          _nilaiAwalSenMeta,
        ),
      );
    }
    if (data.containsKey('likuid')) {
      context.handle(
        _likuidMeta,
        likuid.isAcceptableOrUnknown(data['likuid']!, _likuidMeta),
      );
    }
    if (data.containsKey('arsip')) {
      context.handle(
        _arsipMeta,
        arsip.isAcceptableOrUnknown(data['arsip']!, _arsipMeta),
      );
    }
    if (data.containsKey('catatan')) {
      context.handle(
        _catatanMeta,
        catatan.isAcceptableOrUnknown(data['catatan']!, _catatanMeta),
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
  AsetData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AsetData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      idAset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id_aset'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      jenis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jenis'],
      )!,
      institusi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institusi'],
      ),
      kodeMataUang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kode_mata_uang'],
      )!,
      nilaiAwalSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nilai_awal_sen'],
      )!,
      likuid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}likuid'],
      )!,
      arsip: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}arsip'],
      )!,
      catatan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catatan'],
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
  $AsetTable createAlias(String alias) {
    return $AsetTable(attachedDatabase, alias);
  }
}

class AsetData extends DataClass implements Insertable<AsetData> {
  final int id;

  /// Unik. Pengenal stabil untuk impor/ekspor & sinkron.
  final String idAset;
  final String nama;

  /// JenisAset: kas / bank / investasi / properti / kendaraan / emas /
  /// kripto / bisnis / lain.
  final String jenis;
  final String? institusi;
  final String kodeMataUang;

  /// Nilai saat aset didaftarkan (sen) — dipakai bila belum ada nilai bulanan.
  final int nilaiAwalSen;

  /// true = dana siap pakai.
  final bool likuid;

  /// true = disembunyikan; riwayat nilai tetap ada. Dipakai sebagai ganti
  /// hapus selama riwayat masih ada (keputusan rancangan §4.6).
  final bool arsip;
  final String? catatan;
  final DateTime dibuatPada;
  final DateTime diubahPada;
  const AsetData({
    required this.id,
    required this.idAset,
    required this.nama,
    required this.jenis,
    this.institusi,
    required this.kodeMataUang,
    required this.nilaiAwalSen,
    required this.likuid,
    required this.arsip,
    this.catatan,
    required this.dibuatPada,
    required this.diubahPada,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['id_aset'] = Variable<String>(idAset);
    map['nama'] = Variable<String>(nama);
    map['jenis'] = Variable<String>(jenis);
    if (!nullToAbsent || institusi != null) {
      map['institusi'] = Variable<String>(institusi);
    }
    map['kode_mata_uang'] = Variable<String>(kodeMataUang);
    map['nilai_awal_sen'] = Variable<int>(nilaiAwalSen);
    map['likuid'] = Variable<bool>(likuid);
    map['arsip'] = Variable<bool>(arsip);
    if (!nullToAbsent || catatan != null) {
      map['catatan'] = Variable<String>(catatan);
    }
    map['dibuat_pada'] = Variable<DateTime>(dibuatPada);
    map['diubah_pada'] = Variable<DateTime>(diubahPada);
    return map;
  }

  AsetCompanion toCompanion(bool nullToAbsent) {
    return AsetCompanion(
      id: Value(id),
      idAset: Value(idAset),
      nama: Value(nama),
      jenis: Value(jenis),
      institusi: institusi == null && nullToAbsent
          ? const Value.absent()
          : Value(institusi),
      kodeMataUang: Value(kodeMataUang),
      nilaiAwalSen: Value(nilaiAwalSen),
      likuid: Value(likuid),
      arsip: Value(arsip),
      catatan: catatan == null && nullToAbsent
          ? const Value.absent()
          : Value(catatan),
      dibuatPada: Value(dibuatPada),
      diubahPada: Value(diubahPada),
    );
  }

  factory AsetData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AsetData(
      id: serializer.fromJson<int>(json['id']),
      idAset: serializer.fromJson<String>(json['idAset']),
      nama: serializer.fromJson<String>(json['nama']),
      jenis: serializer.fromJson<String>(json['jenis']),
      institusi: serializer.fromJson<String?>(json['institusi']),
      kodeMataUang: serializer.fromJson<String>(json['kodeMataUang']),
      nilaiAwalSen: serializer.fromJson<int>(json['nilaiAwalSen']),
      likuid: serializer.fromJson<bool>(json['likuid']),
      arsip: serializer.fromJson<bool>(json['arsip']),
      catatan: serializer.fromJson<String?>(json['catatan']),
      dibuatPada: serializer.fromJson<DateTime>(json['dibuatPada']),
      diubahPada: serializer.fromJson<DateTime>(json['diubahPada']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'idAset': serializer.toJson<String>(idAset),
      'nama': serializer.toJson<String>(nama),
      'jenis': serializer.toJson<String>(jenis),
      'institusi': serializer.toJson<String?>(institusi),
      'kodeMataUang': serializer.toJson<String>(kodeMataUang),
      'nilaiAwalSen': serializer.toJson<int>(nilaiAwalSen),
      'likuid': serializer.toJson<bool>(likuid),
      'arsip': serializer.toJson<bool>(arsip),
      'catatan': serializer.toJson<String?>(catatan),
      'dibuatPada': serializer.toJson<DateTime>(dibuatPada),
      'diubahPada': serializer.toJson<DateTime>(diubahPada),
    };
  }

  AsetData copyWith({
    int? id,
    String? idAset,
    String? nama,
    String? jenis,
    Value<String?> institusi = const Value.absent(),
    String? kodeMataUang,
    int? nilaiAwalSen,
    bool? likuid,
    bool? arsip,
    Value<String?> catatan = const Value.absent(),
    DateTime? dibuatPada,
    DateTime? diubahPada,
  }) => AsetData(
    id: id ?? this.id,
    idAset: idAset ?? this.idAset,
    nama: nama ?? this.nama,
    jenis: jenis ?? this.jenis,
    institusi: institusi.present ? institusi.value : this.institusi,
    kodeMataUang: kodeMataUang ?? this.kodeMataUang,
    nilaiAwalSen: nilaiAwalSen ?? this.nilaiAwalSen,
    likuid: likuid ?? this.likuid,
    arsip: arsip ?? this.arsip,
    catatan: catatan.present ? catatan.value : this.catatan,
    dibuatPada: dibuatPada ?? this.dibuatPada,
    diubahPada: diubahPada ?? this.diubahPada,
  );
  AsetData copyWithCompanion(AsetCompanion data) {
    return AsetData(
      id: data.id.present ? data.id.value : this.id,
      idAset: data.idAset.present ? data.idAset.value : this.idAset,
      nama: data.nama.present ? data.nama.value : this.nama,
      jenis: data.jenis.present ? data.jenis.value : this.jenis,
      institusi: data.institusi.present ? data.institusi.value : this.institusi,
      kodeMataUang: data.kodeMataUang.present
          ? data.kodeMataUang.value
          : this.kodeMataUang,
      nilaiAwalSen: data.nilaiAwalSen.present
          ? data.nilaiAwalSen.value
          : this.nilaiAwalSen,
      likuid: data.likuid.present ? data.likuid.value : this.likuid,
      arsip: data.arsip.present ? data.arsip.value : this.arsip,
      catatan: data.catatan.present ? data.catatan.value : this.catatan,
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
    return (StringBuffer('AsetData(')
          ..write('id: $id, ')
          ..write('idAset: $idAset, ')
          ..write('nama: $nama, ')
          ..write('jenis: $jenis, ')
          ..write('institusi: $institusi, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('nilaiAwalSen: $nilaiAwalSen, ')
          ..write('likuid: $likuid, ')
          ..write('arsip: $arsip, ')
          ..write('catatan: $catatan, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    idAset,
    nama,
    jenis,
    institusi,
    kodeMataUang,
    nilaiAwalSen,
    likuid,
    arsip,
    catatan,
    dibuatPada,
    diubahPada,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AsetData &&
          other.id == this.id &&
          other.idAset == this.idAset &&
          other.nama == this.nama &&
          other.jenis == this.jenis &&
          other.institusi == this.institusi &&
          other.kodeMataUang == this.kodeMataUang &&
          other.nilaiAwalSen == this.nilaiAwalSen &&
          other.likuid == this.likuid &&
          other.arsip == this.arsip &&
          other.catatan == this.catatan &&
          other.dibuatPada == this.dibuatPada &&
          other.diubahPada == this.diubahPada);
}

class AsetCompanion extends UpdateCompanion<AsetData> {
  final Value<int> id;
  final Value<String> idAset;
  final Value<String> nama;
  final Value<String> jenis;
  final Value<String?> institusi;
  final Value<String> kodeMataUang;
  final Value<int> nilaiAwalSen;
  final Value<bool> likuid;
  final Value<bool> arsip;
  final Value<String?> catatan;
  final Value<DateTime> dibuatPada;
  final Value<DateTime> diubahPada;
  const AsetCompanion({
    this.id = const Value.absent(),
    this.idAset = const Value.absent(),
    this.nama = const Value.absent(),
    this.jenis = const Value.absent(),
    this.institusi = const Value.absent(),
    this.kodeMataUang = const Value.absent(),
    this.nilaiAwalSen = const Value.absent(),
    this.likuid = const Value.absent(),
    this.arsip = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  });
  AsetCompanion.insert({
    this.id = const Value.absent(),
    required String idAset,
    required String nama,
    this.jenis = const Value.absent(),
    this.institusi = const Value.absent(),
    this.kodeMataUang = const Value.absent(),
    this.nilaiAwalSen = const Value.absent(),
    this.likuid = const Value.absent(),
    this.arsip = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  }) : idAset = Value(idAset),
       nama = Value(nama);
  static Insertable<AsetData> custom({
    Expression<int>? id,
    Expression<String>? idAset,
    Expression<String>? nama,
    Expression<String>? jenis,
    Expression<String>? institusi,
    Expression<String>? kodeMataUang,
    Expression<int>? nilaiAwalSen,
    Expression<bool>? likuid,
    Expression<bool>? arsip,
    Expression<String>? catatan,
    Expression<DateTime>? dibuatPada,
    Expression<DateTime>? diubahPada,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idAset != null) 'id_aset': idAset,
      if (nama != null) 'nama': nama,
      if (jenis != null) 'jenis': jenis,
      if (institusi != null) 'institusi': institusi,
      if (kodeMataUang != null) 'kode_mata_uang': kodeMataUang,
      if (nilaiAwalSen != null) 'nilai_awal_sen': nilaiAwalSen,
      if (likuid != null) 'likuid': likuid,
      if (arsip != null) 'arsip': arsip,
      if (catatan != null) 'catatan': catatan,
      if (dibuatPada != null) 'dibuat_pada': dibuatPada,
      if (diubahPada != null) 'diubah_pada': diubahPada,
    });
  }

  AsetCompanion copyWith({
    Value<int>? id,
    Value<String>? idAset,
    Value<String>? nama,
    Value<String>? jenis,
    Value<String?>? institusi,
    Value<String>? kodeMataUang,
    Value<int>? nilaiAwalSen,
    Value<bool>? likuid,
    Value<bool>? arsip,
    Value<String?>? catatan,
    Value<DateTime>? dibuatPada,
    Value<DateTime>? diubahPada,
  }) {
    return AsetCompanion(
      id: id ?? this.id,
      idAset: idAset ?? this.idAset,
      nama: nama ?? this.nama,
      jenis: jenis ?? this.jenis,
      institusi: institusi ?? this.institusi,
      kodeMataUang: kodeMataUang ?? this.kodeMataUang,
      nilaiAwalSen: nilaiAwalSen ?? this.nilaiAwalSen,
      likuid: likuid ?? this.likuid,
      arsip: arsip ?? this.arsip,
      catatan: catatan ?? this.catatan,
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
    if (idAset.present) {
      map['id_aset'] = Variable<String>(idAset.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (jenis.present) {
      map['jenis'] = Variable<String>(jenis.value);
    }
    if (institusi.present) {
      map['institusi'] = Variable<String>(institusi.value);
    }
    if (kodeMataUang.present) {
      map['kode_mata_uang'] = Variable<String>(kodeMataUang.value);
    }
    if (nilaiAwalSen.present) {
      map['nilai_awal_sen'] = Variable<int>(nilaiAwalSen.value);
    }
    if (likuid.present) {
      map['likuid'] = Variable<bool>(likuid.value);
    }
    if (arsip.present) {
      map['arsip'] = Variable<bool>(arsip.value);
    }
    if (catatan.present) {
      map['catatan'] = Variable<String>(catatan.value);
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
    return (StringBuffer('AsetCompanion(')
          ..write('id: $id, ')
          ..write('idAset: $idAset, ')
          ..write('nama: $nama, ')
          ..write('jenis: $jenis, ')
          ..write('institusi: $institusi, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('nilaiAwalSen: $nilaiAwalSen, ')
          ..write('likuid: $likuid, ')
          ..write('arsip: $arsip, ')
          ..write('catatan: $catatan, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }
}

class $KewajibanTable extends Kewajiban
    with TableInfo<$KewajibanTable, KewajibanData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KewajibanTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _idKewajibanMeta = const VerificationMeta(
    'idKewajiban',
  );
  @override
  late final GeneratedColumn<String> idKewajiban = GeneratedColumn<String>(
    'id_kewajiban',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _jenisMeta = const VerificationMeta('jenis');
  @override
  late final GeneratedColumn<String> jenis = GeneratedColumn<String>(
    'jenis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('lain'),
  );
  static const VerificationMeta _pokokSenMeta = const VerificationMeta(
    'pokokSen',
  );
  @override
  late final GeneratedColumn<int> pokokSen = GeneratedColumn<int>(
    'pokok_sen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _saldoAwalSenMeta = const VerificationMeta(
    'saldoAwalSen',
  );
  @override
  late final GeneratedColumn<int> saldoAwalSen = GeneratedColumn<int>(
    'saldo_awal_sen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sukuBungaPersenTahunMeta =
      const VerificationMeta('sukuBungaPersenTahun');
  @override
  late final GeneratedColumn<double> sukuBungaPersenTahun =
      GeneratedColumn<double>(
        'suku_bunga_persen_tahun',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _minimumBayarSenMeta = const VerificationMeta(
    'minimumBayarSen',
  );
  @override
  late final GeneratedColumn<int> minimumBayarSen = GeneratedColumn<int>(
    'minimum_bayar_sen',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tanggalJatuhTempoHariMeta =
      const VerificationMeta('tanggalJatuhTempoHari');
  @override
  late final GeneratedColumn<int> tanggalJatuhTempoHari = GeneratedColumn<int>(
    'tanggal_jatuh_tempo_hari',
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
  static const VerificationMeta _arsipMeta = const VerificationMeta('arsip');
  @override
  late final GeneratedColumn<bool> arsip = GeneratedColumn<bool>(
    'arsip',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("arsip" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    idKewajiban,
    nama,
    jenis,
    pokokSen,
    saldoAwalSen,
    sukuBungaPersenTahun,
    minimumBayarSen,
    tanggalJatuhTempoHari,
    kodeMataUang,
    arsip,
    catatan,
    dibuatPada,
    diubahPada,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kewajiban';
  @override
  VerificationContext validateIntegrity(
    Insertable<KewajibanData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('id_kewajiban')) {
      context.handle(
        _idKewajibanMeta,
        idKewajiban.isAcceptableOrUnknown(
          data['id_kewajiban']!,
          _idKewajibanMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idKewajibanMeta);
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('jenis')) {
      context.handle(
        _jenisMeta,
        jenis.isAcceptableOrUnknown(data['jenis']!, _jenisMeta),
      );
    }
    if (data.containsKey('pokok_sen')) {
      context.handle(
        _pokokSenMeta,
        pokokSen.isAcceptableOrUnknown(data['pokok_sen']!, _pokokSenMeta),
      );
    }
    if (data.containsKey('saldo_awal_sen')) {
      context.handle(
        _saldoAwalSenMeta,
        saldoAwalSen.isAcceptableOrUnknown(
          data['saldo_awal_sen']!,
          _saldoAwalSenMeta,
        ),
      );
    }
    if (data.containsKey('suku_bunga_persen_tahun')) {
      context.handle(
        _sukuBungaPersenTahunMeta,
        sukuBungaPersenTahun.isAcceptableOrUnknown(
          data['suku_bunga_persen_tahun']!,
          _sukuBungaPersenTahunMeta,
        ),
      );
    }
    if (data.containsKey('minimum_bayar_sen')) {
      context.handle(
        _minimumBayarSenMeta,
        minimumBayarSen.isAcceptableOrUnknown(
          data['minimum_bayar_sen']!,
          _minimumBayarSenMeta,
        ),
      );
    }
    if (data.containsKey('tanggal_jatuh_tempo_hari')) {
      context.handle(
        _tanggalJatuhTempoHariMeta,
        tanggalJatuhTempoHari.isAcceptableOrUnknown(
          data['tanggal_jatuh_tempo_hari']!,
          _tanggalJatuhTempoHariMeta,
        ),
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
    if (data.containsKey('arsip')) {
      context.handle(
        _arsipMeta,
        arsip.isAcceptableOrUnknown(data['arsip']!, _arsipMeta),
      );
    }
    if (data.containsKey('catatan')) {
      context.handle(
        _catatanMeta,
        catatan.isAcceptableOrUnknown(data['catatan']!, _catatanMeta),
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
  KewajibanData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KewajibanData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      idKewajiban: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id_kewajiban'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      jenis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jenis'],
      )!,
      pokokSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pokok_sen'],
      )!,
      saldoAwalSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saldo_awal_sen'],
      )!,
      sukuBungaPersenTahun: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}suku_bunga_persen_tahun'],
      ),
      minimumBayarSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minimum_bayar_sen'],
      ),
      tanggalJatuhTempoHari: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tanggal_jatuh_tempo_hari'],
      ),
      kodeMataUang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kode_mata_uang'],
      )!,
      arsip: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}arsip'],
      )!,
      catatan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catatan'],
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
  $KewajibanTable createAlias(String alias) {
    return $KewajibanTable(attachedDatabase, alias);
  }
}

class KewajibanData extends DataClass implements Insertable<KewajibanData> {
  final int id;
  final String idKewajiban;
  final String nama;

  /// JenisKewajiban: kartu_kredit / kpr / pinjaman / cicilan / lain.
  final String jenis;
  final int pokokSen;

  /// Sisa saat didaftarkan (sen) — dipakai bila belum ada nilai bulanan.
  final int saldoAwalSen;

  /// Bukan nilai uang; null = belum diketahui. Tidak dipakai sebelum FR-74.
  final double? sukuBungaPersenTahun;
  final int? minimumBayarSen;

  /// Hari 1–31 dalam bulan (bahan pengingat cicilan, FR-74).
  final int? tanggalJatuhTempoHari;
  final String kodeMataUang;
  final bool arsip;
  final String? catatan;
  final DateTime dibuatPada;
  final DateTime diubahPada;
  const KewajibanData({
    required this.id,
    required this.idKewajiban,
    required this.nama,
    required this.jenis,
    required this.pokokSen,
    required this.saldoAwalSen,
    this.sukuBungaPersenTahun,
    this.minimumBayarSen,
    this.tanggalJatuhTempoHari,
    required this.kodeMataUang,
    required this.arsip,
    this.catatan,
    required this.dibuatPada,
    required this.diubahPada,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['id_kewajiban'] = Variable<String>(idKewajiban);
    map['nama'] = Variable<String>(nama);
    map['jenis'] = Variable<String>(jenis);
    map['pokok_sen'] = Variable<int>(pokokSen);
    map['saldo_awal_sen'] = Variable<int>(saldoAwalSen);
    if (!nullToAbsent || sukuBungaPersenTahun != null) {
      map['suku_bunga_persen_tahun'] = Variable<double>(sukuBungaPersenTahun);
    }
    if (!nullToAbsent || minimumBayarSen != null) {
      map['minimum_bayar_sen'] = Variable<int>(minimumBayarSen);
    }
    if (!nullToAbsent || tanggalJatuhTempoHari != null) {
      map['tanggal_jatuh_tempo_hari'] = Variable<int>(tanggalJatuhTempoHari);
    }
    map['kode_mata_uang'] = Variable<String>(kodeMataUang);
    map['arsip'] = Variable<bool>(arsip);
    if (!nullToAbsent || catatan != null) {
      map['catatan'] = Variable<String>(catatan);
    }
    map['dibuat_pada'] = Variable<DateTime>(dibuatPada);
    map['diubah_pada'] = Variable<DateTime>(diubahPada);
    return map;
  }

  KewajibanCompanion toCompanion(bool nullToAbsent) {
    return KewajibanCompanion(
      id: Value(id),
      idKewajiban: Value(idKewajiban),
      nama: Value(nama),
      jenis: Value(jenis),
      pokokSen: Value(pokokSen),
      saldoAwalSen: Value(saldoAwalSen),
      sukuBungaPersenTahun: sukuBungaPersenTahun == null && nullToAbsent
          ? const Value.absent()
          : Value(sukuBungaPersenTahun),
      minimumBayarSen: minimumBayarSen == null && nullToAbsent
          ? const Value.absent()
          : Value(minimumBayarSen),
      tanggalJatuhTempoHari: tanggalJatuhTempoHari == null && nullToAbsent
          ? const Value.absent()
          : Value(tanggalJatuhTempoHari),
      kodeMataUang: Value(kodeMataUang),
      arsip: Value(arsip),
      catatan: catatan == null && nullToAbsent
          ? const Value.absent()
          : Value(catatan),
      dibuatPada: Value(dibuatPada),
      diubahPada: Value(diubahPada),
    );
  }

  factory KewajibanData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KewajibanData(
      id: serializer.fromJson<int>(json['id']),
      idKewajiban: serializer.fromJson<String>(json['idKewajiban']),
      nama: serializer.fromJson<String>(json['nama']),
      jenis: serializer.fromJson<String>(json['jenis']),
      pokokSen: serializer.fromJson<int>(json['pokokSen']),
      saldoAwalSen: serializer.fromJson<int>(json['saldoAwalSen']),
      sukuBungaPersenTahun: serializer.fromJson<double?>(
        json['sukuBungaPersenTahun'],
      ),
      minimumBayarSen: serializer.fromJson<int?>(json['minimumBayarSen']),
      tanggalJatuhTempoHari: serializer.fromJson<int?>(
        json['tanggalJatuhTempoHari'],
      ),
      kodeMataUang: serializer.fromJson<String>(json['kodeMataUang']),
      arsip: serializer.fromJson<bool>(json['arsip']),
      catatan: serializer.fromJson<String?>(json['catatan']),
      dibuatPada: serializer.fromJson<DateTime>(json['dibuatPada']),
      diubahPada: serializer.fromJson<DateTime>(json['diubahPada']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'idKewajiban': serializer.toJson<String>(idKewajiban),
      'nama': serializer.toJson<String>(nama),
      'jenis': serializer.toJson<String>(jenis),
      'pokokSen': serializer.toJson<int>(pokokSen),
      'saldoAwalSen': serializer.toJson<int>(saldoAwalSen),
      'sukuBungaPersenTahun': serializer.toJson<double?>(sukuBungaPersenTahun),
      'minimumBayarSen': serializer.toJson<int?>(minimumBayarSen),
      'tanggalJatuhTempoHari': serializer.toJson<int?>(tanggalJatuhTempoHari),
      'kodeMataUang': serializer.toJson<String>(kodeMataUang),
      'arsip': serializer.toJson<bool>(arsip),
      'catatan': serializer.toJson<String?>(catatan),
      'dibuatPada': serializer.toJson<DateTime>(dibuatPada),
      'diubahPada': serializer.toJson<DateTime>(diubahPada),
    };
  }

  KewajibanData copyWith({
    int? id,
    String? idKewajiban,
    String? nama,
    String? jenis,
    int? pokokSen,
    int? saldoAwalSen,
    Value<double?> sukuBungaPersenTahun = const Value.absent(),
    Value<int?> minimumBayarSen = const Value.absent(),
    Value<int?> tanggalJatuhTempoHari = const Value.absent(),
    String? kodeMataUang,
    bool? arsip,
    Value<String?> catatan = const Value.absent(),
    DateTime? dibuatPada,
    DateTime? diubahPada,
  }) => KewajibanData(
    id: id ?? this.id,
    idKewajiban: idKewajiban ?? this.idKewajiban,
    nama: nama ?? this.nama,
    jenis: jenis ?? this.jenis,
    pokokSen: pokokSen ?? this.pokokSen,
    saldoAwalSen: saldoAwalSen ?? this.saldoAwalSen,
    sukuBungaPersenTahun: sukuBungaPersenTahun.present
        ? sukuBungaPersenTahun.value
        : this.sukuBungaPersenTahun,
    minimumBayarSen: minimumBayarSen.present
        ? minimumBayarSen.value
        : this.minimumBayarSen,
    tanggalJatuhTempoHari: tanggalJatuhTempoHari.present
        ? tanggalJatuhTempoHari.value
        : this.tanggalJatuhTempoHari,
    kodeMataUang: kodeMataUang ?? this.kodeMataUang,
    arsip: arsip ?? this.arsip,
    catatan: catatan.present ? catatan.value : this.catatan,
    dibuatPada: dibuatPada ?? this.dibuatPada,
    diubahPada: diubahPada ?? this.diubahPada,
  );
  KewajibanData copyWithCompanion(KewajibanCompanion data) {
    return KewajibanData(
      id: data.id.present ? data.id.value : this.id,
      idKewajiban: data.idKewajiban.present
          ? data.idKewajiban.value
          : this.idKewajiban,
      nama: data.nama.present ? data.nama.value : this.nama,
      jenis: data.jenis.present ? data.jenis.value : this.jenis,
      pokokSen: data.pokokSen.present ? data.pokokSen.value : this.pokokSen,
      saldoAwalSen: data.saldoAwalSen.present
          ? data.saldoAwalSen.value
          : this.saldoAwalSen,
      sukuBungaPersenTahun: data.sukuBungaPersenTahun.present
          ? data.sukuBungaPersenTahun.value
          : this.sukuBungaPersenTahun,
      minimumBayarSen: data.minimumBayarSen.present
          ? data.minimumBayarSen.value
          : this.minimumBayarSen,
      tanggalJatuhTempoHari: data.tanggalJatuhTempoHari.present
          ? data.tanggalJatuhTempoHari.value
          : this.tanggalJatuhTempoHari,
      kodeMataUang: data.kodeMataUang.present
          ? data.kodeMataUang.value
          : this.kodeMataUang,
      arsip: data.arsip.present ? data.arsip.value : this.arsip,
      catatan: data.catatan.present ? data.catatan.value : this.catatan,
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
    return (StringBuffer('KewajibanData(')
          ..write('id: $id, ')
          ..write('idKewajiban: $idKewajiban, ')
          ..write('nama: $nama, ')
          ..write('jenis: $jenis, ')
          ..write('pokokSen: $pokokSen, ')
          ..write('saldoAwalSen: $saldoAwalSen, ')
          ..write('sukuBungaPersenTahun: $sukuBungaPersenTahun, ')
          ..write('minimumBayarSen: $minimumBayarSen, ')
          ..write('tanggalJatuhTempoHari: $tanggalJatuhTempoHari, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('arsip: $arsip, ')
          ..write('catatan: $catatan, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    idKewajiban,
    nama,
    jenis,
    pokokSen,
    saldoAwalSen,
    sukuBungaPersenTahun,
    minimumBayarSen,
    tanggalJatuhTempoHari,
    kodeMataUang,
    arsip,
    catatan,
    dibuatPada,
    diubahPada,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KewajibanData &&
          other.id == this.id &&
          other.idKewajiban == this.idKewajiban &&
          other.nama == this.nama &&
          other.jenis == this.jenis &&
          other.pokokSen == this.pokokSen &&
          other.saldoAwalSen == this.saldoAwalSen &&
          other.sukuBungaPersenTahun == this.sukuBungaPersenTahun &&
          other.minimumBayarSen == this.minimumBayarSen &&
          other.tanggalJatuhTempoHari == this.tanggalJatuhTempoHari &&
          other.kodeMataUang == this.kodeMataUang &&
          other.arsip == this.arsip &&
          other.catatan == this.catatan &&
          other.dibuatPada == this.dibuatPada &&
          other.diubahPada == this.diubahPada);
}

class KewajibanCompanion extends UpdateCompanion<KewajibanData> {
  final Value<int> id;
  final Value<String> idKewajiban;
  final Value<String> nama;
  final Value<String> jenis;
  final Value<int> pokokSen;
  final Value<int> saldoAwalSen;
  final Value<double?> sukuBungaPersenTahun;
  final Value<int?> minimumBayarSen;
  final Value<int?> tanggalJatuhTempoHari;
  final Value<String> kodeMataUang;
  final Value<bool> arsip;
  final Value<String?> catatan;
  final Value<DateTime> dibuatPada;
  final Value<DateTime> diubahPada;
  const KewajibanCompanion({
    this.id = const Value.absent(),
    this.idKewajiban = const Value.absent(),
    this.nama = const Value.absent(),
    this.jenis = const Value.absent(),
    this.pokokSen = const Value.absent(),
    this.saldoAwalSen = const Value.absent(),
    this.sukuBungaPersenTahun = const Value.absent(),
    this.minimumBayarSen = const Value.absent(),
    this.tanggalJatuhTempoHari = const Value.absent(),
    this.kodeMataUang = const Value.absent(),
    this.arsip = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  });
  KewajibanCompanion.insert({
    this.id = const Value.absent(),
    required String idKewajiban,
    required String nama,
    this.jenis = const Value.absent(),
    this.pokokSen = const Value.absent(),
    this.saldoAwalSen = const Value.absent(),
    this.sukuBungaPersenTahun = const Value.absent(),
    this.minimumBayarSen = const Value.absent(),
    this.tanggalJatuhTempoHari = const Value.absent(),
    this.kodeMataUang = const Value.absent(),
    this.arsip = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  }) : idKewajiban = Value(idKewajiban),
       nama = Value(nama);
  static Insertable<KewajibanData> custom({
    Expression<int>? id,
    Expression<String>? idKewajiban,
    Expression<String>? nama,
    Expression<String>? jenis,
    Expression<int>? pokokSen,
    Expression<int>? saldoAwalSen,
    Expression<double>? sukuBungaPersenTahun,
    Expression<int>? minimumBayarSen,
    Expression<int>? tanggalJatuhTempoHari,
    Expression<String>? kodeMataUang,
    Expression<bool>? arsip,
    Expression<String>? catatan,
    Expression<DateTime>? dibuatPada,
    Expression<DateTime>? diubahPada,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idKewajiban != null) 'id_kewajiban': idKewajiban,
      if (nama != null) 'nama': nama,
      if (jenis != null) 'jenis': jenis,
      if (pokokSen != null) 'pokok_sen': pokokSen,
      if (saldoAwalSen != null) 'saldo_awal_sen': saldoAwalSen,
      if (sukuBungaPersenTahun != null)
        'suku_bunga_persen_tahun': sukuBungaPersenTahun,
      if (minimumBayarSen != null) 'minimum_bayar_sen': minimumBayarSen,
      if (tanggalJatuhTempoHari != null)
        'tanggal_jatuh_tempo_hari': tanggalJatuhTempoHari,
      if (kodeMataUang != null) 'kode_mata_uang': kodeMataUang,
      if (arsip != null) 'arsip': arsip,
      if (catatan != null) 'catatan': catatan,
      if (dibuatPada != null) 'dibuat_pada': dibuatPada,
      if (diubahPada != null) 'diubah_pada': diubahPada,
    });
  }

  KewajibanCompanion copyWith({
    Value<int>? id,
    Value<String>? idKewajiban,
    Value<String>? nama,
    Value<String>? jenis,
    Value<int>? pokokSen,
    Value<int>? saldoAwalSen,
    Value<double?>? sukuBungaPersenTahun,
    Value<int?>? minimumBayarSen,
    Value<int?>? tanggalJatuhTempoHari,
    Value<String>? kodeMataUang,
    Value<bool>? arsip,
    Value<String?>? catatan,
    Value<DateTime>? dibuatPada,
    Value<DateTime>? diubahPada,
  }) {
    return KewajibanCompanion(
      id: id ?? this.id,
      idKewajiban: idKewajiban ?? this.idKewajiban,
      nama: nama ?? this.nama,
      jenis: jenis ?? this.jenis,
      pokokSen: pokokSen ?? this.pokokSen,
      saldoAwalSen: saldoAwalSen ?? this.saldoAwalSen,
      sukuBungaPersenTahun: sukuBungaPersenTahun ?? this.sukuBungaPersenTahun,
      minimumBayarSen: minimumBayarSen ?? this.minimumBayarSen,
      tanggalJatuhTempoHari:
          tanggalJatuhTempoHari ?? this.tanggalJatuhTempoHari,
      kodeMataUang: kodeMataUang ?? this.kodeMataUang,
      arsip: arsip ?? this.arsip,
      catatan: catatan ?? this.catatan,
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
    if (idKewajiban.present) {
      map['id_kewajiban'] = Variable<String>(idKewajiban.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (jenis.present) {
      map['jenis'] = Variable<String>(jenis.value);
    }
    if (pokokSen.present) {
      map['pokok_sen'] = Variable<int>(pokokSen.value);
    }
    if (saldoAwalSen.present) {
      map['saldo_awal_sen'] = Variable<int>(saldoAwalSen.value);
    }
    if (sukuBungaPersenTahun.present) {
      map['suku_bunga_persen_tahun'] = Variable<double>(
        sukuBungaPersenTahun.value,
      );
    }
    if (minimumBayarSen.present) {
      map['minimum_bayar_sen'] = Variable<int>(minimumBayarSen.value);
    }
    if (tanggalJatuhTempoHari.present) {
      map['tanggal_jatuh_tempo_hari'] = Variable<int>(
        tanggalJatuhTempoHari.value,
      );
    }
    if (kodeMataUang.present) {
      map['kode_mata_uang'] = Variable<String>(kodeMataUang.value);
    }
    if (arsip.present) {
      map['arsip'] = Variable<bool>(arsip.value);
    }
    if (catatan.present) {
      map['catatan'] = Variable<String>(catatan.value);
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
    return (StringBuffer('KewajibanCompanion(')
          ..write('id: $id, ')
          ..write('idKewajiban: $idKewajiban, ')
          ..write('nama: $nama, ')
          ..write('jenis: $jenis, ')
          ..write('pokokSen: $pokokSen, ')
          ..write('saldoAwalSen: $saldoAwalSen, ')
          ..write('sukuBungaPersenTahun: $sukuBungaPersenTahun, ')
          ..write('minimumBayarSen: $minimumBayarSen, ')
          ..write('tanggalJatuhTempoHari: $tanggalJatuhTempoHari, ')
          ..write('kodeMataUang: $kodeMataUang, ')
          ..write('arsip: $arsip, ')
          ..write('catatan: $catatan, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }
}

class $NilaiAsetBulananTable extends NilaiAsetBulanan
    with TableInfo<$NilaiAsetBulananTable, NilaiAsetBulananData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NilaiAsetBulananTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _asetIdMeta = const VerificationMeta('asetId');
  @override
  late final GeneratedColumn<int> asetId = GeneratedColumn<int>(
    'aset_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES aset (id)',
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
  static const VerificationMeta _nilaiSenMeta = const VerificationMeta(
    'nilaiSen',
  );
  @override
  late final GeneratedColumn<int> nilaiSen = GeneratedColumn<int>(
    'nilai_sen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sumberMeta = const VerificationMeta('sumber');
  @override
  late final GeneratedColumn<String> sumber = GeneratedColumn<String>(
    'sumber',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _idempotensiMeta = const VerificationMeta(
    'idempotensi',
  );
  @override
  late final GeneratedColumn<String> idempotensi = GeneratedColumn<String>(
    'idempotensi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _terkunciMeta = const VerificationMeta(
    'terkunci',
  );
  @override
  late final GeneratedColumn<bool> terkunci = GeneratedColumn<bool>(
    'terkunci',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("terkunci" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dikunciPadaMeta = const VerificationMeta(
    'dikunciPada',
  );
  @override
  late final GeneratedColumn<DateTime> dikunciPada = GeneratedColumn<DateTime>(
    'dikunci_pada',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  static const VerificationMeta _dibukaKunciPadaMeta = const VerificationMeta(
    'dibukaKunciPada',
  );
  @override
  late final GeneratedColumn<DateTime> dibukaKunciPada =
      GeneratedColumn<DateTime>(
        'dibuka_kunci_pada',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _alasanBukaKunciMeta = const VerificationMeta(
    'alasanBukaKunci',
  );
  @override
  late final GeneratedColumn<String> alasanBukaKunci = GeneratedColumn<String>(
    'alasan_buka_kunci',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    asetId,
    bulan,
    nilaiSen,
    sumber,
    idempotensi,
    terkunci,
    dikunciPada,
    catatan,
    dibukaKunciPada,
    alasanBukaKunci,
    dibuatPada,
    diubahPada,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nilai_aset_bulanan';
  @override
  VerificationContext validateIntegrity(
    Insertable<NilaiAsetBulananData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('aset_id')) {
      context.handle(
        _asetIdMeta,
        asetId.isAcceptableOrUnknown(data['aset_id']!, _asetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_asetIdMeta);
    }
    if (data.containsKey('bulan')) {
      context.handle(
        _bulanMeta,
        bulan.isAcceptableOrUnknown(data['bulan']!, _bulanMeta),
      );
    } else if (isInserting) {
      context.missing(_bulanMeta);
    }
    if (data.containsKey('nilai_sen')) {
      context.handle(
        _nilaiSenMeta,
        nilaiSen.isAcceptableOrUnknown(data['nilai_sen']!, _nilaiSenMeta),
      );
    } else if (isInserting) {
      context.missing(_nilaiSenMeta);
    }
    if (data.containsKey('sumber')) {
      context.handle(
        _sumberMeta,
        sumber.isAcceptableOrUnknown(data['sumber']!, _sumberMeta),
      );
    }
    if (data.containsKey('idempotensi')) {
      context.handle(
        _idempotensiMeta,
        idempotensi.isAcceptableOrUnknown(
          data['idempotensi']!,
          _idempotensiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotensiMeta);
    }
    if (data.containsKey('terkunci')) {
      context.handle(
        _terkunciMeta,
        terkunci.isAcceptableOrUnknown(data['terkunci']!, _terkunciMeta),
      );
    }
    if (data.containsKey('dikunci_pada')) {
      context.handle(
        _dikunciPadaMeta,
        dikunciPada.isAcceptableOrUnknown(
          data['dikunci_pada']!,
          _dikunciPadaMeta,
        ),
      );
    }
    if (data.containsKey('catatan')) {
      context.handle(
        _catatanMeta,
        catatan.isAcceptableOrUnknown(data['catatan']!, _catatanMeta),
      );
    }
    if (data.containsKey('dibuka_kunci_pada')) {
      context.handle(
        _dibukaKunciPadaMeta,
        dibukaKunciPada.isAcceptableOrUnknown(
          data['dibuka_kunci_pada']!,
          _dibukaKunciPadaMeta,
        ),
      );
    }
    if (data.containsKey('alasan_buka_kunci')) {
      context.handle(
        _alasanBukaKunciMeta,
        alasanBukaKunci.isAcceptableOrUnknown(
          data['alasan_buka_kunci']!,
          _alasanBukaKunciMeta,
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
  NilaiAsetBulananData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NilaiAsetBulananData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      asetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}aset_id'],
      )!,
      bulan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bulan'],
      )!,
      nilaiSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nilai_sen'],
      )!,
      sumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sumber'],
      )!,
      idempotensi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotensi'],
      )!,
      terkunci: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}terkunci'],
      )!,
      dikunciPada: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dikunci_pada'],
      ),
      catatan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catatan'],
      ),
      dibukaKunciPada: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dibuka_kunci_pada'],
      ),
      alasanBukaKunci: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alasan_buka_kunci'],
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
  $NilaiAsetBulananTable createAlias(String alias) {
    return $NilaiAsetBulananTable(attachedDatabase, alias);
  }
}

class NilaiAsetBulananData extends DataClass
    implements Insertable<NilaiAsetBulananData> {
  final int id;
  final int asetId;

  /// 'YYYY-MM'.
  final String bulan;
  final int nilaiSen;

  /// `manual` / `dihitung` / `impor`.
  final String sumber;

  /// Unik, mis. `aset:7:2026-09`.
  final String idempotensi;

  /// true = bulan yang sudah lewat: tidak berubah tanpa permintaan eksplisit.
  final bool terkunci;
  final DateTime? dikunciPada;
  final String? catatan;

  /// Jejak bila pengguna membuka kunci (anti kehilangan data: salah ketik
  /// pada bulan lalu tetap bisa diperbaiki, tetapi meninggalkan jejak).
  final DateTime? dibukaKunciPada;
  final String? alasanBukaKunci;
  final DateTime dibuatPada;
  final DateTime diubahPada;
  const NilaiAsetBulananData({
    required this.id,
    required this.asetId,
    required this.bulan,
    required this.nilaiSen,
    required this.sumber,
    required this.idempotensi,
    required this.terkunci,
    this.dikunciPada,
    this.catatan,
    this.dibukaKunciPada,
    this.alasanBukaKunci,
    required this.dibuatPada,
    required this.diubahPada,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['aset_id'] = Variable<int>(asetId);
    map['bulan'] = Variable<String>(bulan);
    map['nilai_sen'] = Variable<int>(nilaiSen);
    map['sumber'] = Variable<String>(sumber);
    map['idempotensi'] = Variable<String>(idempotensi);
    map['terkunci'] = Variable<bool>(terkunci);
    if (!nullToAbsent || dikunciPada != null) {
      map['dikunci_pada'] = Variable<DateTime>(dikunciPada);
    }
    if (!nullToAbsent || catatan != null) {
      map['catatan'] = Variable<String>(catatan);
    }
    if (!nullToAbsent || dibukaKunciPada != null) {
      map['dibuka_kunci_pada'] = Variable<DateTime>(dibukaKunciPada);
    }
    if (!nullToAbsent || alasanBukaKunci != null) {
      map['alasan_buka_kunci'] = Variable<String>(alasanBukaKunci);
    }
    map['dibuat_pada'] = Variable<DateTime>(dibuatPada);
    map['diubah_pada'] = Variable<DateTime>(diubahPada);
    return map;
  }

  NilaiAsetBulananCompanion toCompanion(bool nullToAbsent) {
    return NilaiAsetBulananCompanion(
      id: Value(id),
      asetId: Value(asetId),
      bulan: Value(bulan),
      nilaiSen: Value(nilaiSen),
      sumber: Value(sumber),
      idempotensi: Value(idempotensi),
      terkunci: Value(terkunci),
      dikunciPada: dikunciPada == null && nullToAbsent
          ? const Value.absent()
          : Value(dikunciPada),
      catatan: catatan == null && nullToAbsent
          ? const Value.absent()
          : Value(catatan),
      dibukaKunciPada: dibukaKunciPada == null && nullToAbsent
          ? const Value.absent()
          : Value(dibukaKunciPada),
      alasanBukaKunci: alasanBukaKunci == null && nullToAbsent
          ? const Value.absent()
          : Value(alasanBukaKunci),
      dibuatPada: Value(dibuatPada),
      diubahPada: Value(diubahPada),
    );
  }

  factory NilaiAsetBulananData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NilaiAsetBulananData(
      id: serializer.fromJson<int>(json['id']),
      asetId: serializer.fromJson<int>(json['asetId']),
      bulan: serializer.fromJson<String>(json['bulan']),
      nilaiSen: serializer.fromJson<int>(json['nilaiSen']),
      sumber: serializer.fromJson<String>(json['sumber']),
      idempotensi: serializer.fromJson<String>(json['idempotensi']),
      terkunci: serializer.fromJson<bool>(json['terkunci']),
      dikunciPada: serializer.fromJson<DateTime?>(json['dikunciPada']),
      catatan: serializer.fromJson<String?>(json['catatan']),
      dibukaKunciPada: serializer.fromJson<DateTime?>(json['dibukaKunciPada']),
      alasanBukaKunci: serializer.fromJson<String?>(json['alasanBukaKunci']),
      dibuatPada: serializer.fromJson<DateTime>(json['dibuatPada']),
      diubahPada: serializer.fromJson<DateTime>(json['diubahPada']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'asetId': serializer.toJson<int>(asetId),
      'bulan': serializer.toJson<String>(bulan),
      'nilaiSen': serializer.toJson<int>(nilaiSen),
      'sumber': serializer.toJson<String>(sumber),
      'idempotensi': serializer.toJson<String>(idempotensi),
      'terkunci': serializer.toJson<bool>(terkunci),
      'dikunciPada': serializer.toJson<DateTime?>(dikunciPada),
      'catatan': serializer.toJson<String?>(catatan),
      'dibukaKunciPada': serializer.toJson<DateTime?>(dibukaKunciPada),
      'alasanBukaKunci': serializer.toJson<String?>(alasanBukaKunci),
      'dibuatPada': serializer.toJson<DateTime>(dibuatPada),
      'diubahPada': serializer.toJson<DateTime>(diubahPada),
    };
  }

  NilaiAsetBulananData copyWith({
    int? id,
    int? asetId,
    String? bulan,
    int? nilaiSen,
    String? sumber,
    String? idempotensi,
    bool? terkunci,
    Value<DateTime?> dikunciPada = const Value.absent(),
    Value<String?> catatan = const Value.absent(),
    Value<DateTime?> dibukaKunciPada = const Value.absent(),
    Value<String?> alasanBukaKunci = const Value.absent(),
    DateTime? dibuatPada,
    DateTime? diubahPada,
  }) => NilaiAsetBulananData(
    id: id ?? this.id,
    asetId: asetId ?? this.asetId,
    bulan: bulan ?? this.bulan,
    nilaiSen: nilaiSen ?? this.nilaiSen,
    sumber: sumber ?? this.sumber,
    idempotensi: idempotensi ?? this.idempotensi,
    terkunci: terkunci ?? this.terkunci,
    dikunciPada: dikunciPada.present ? dikunciPada.value : this.dikunciPada,
    catatan: catatan.present ? catatan.value : this.catatan,
    dibukaKunciPada: dibukaKunciPada.present
        ? dibukaKunciPada.value
        : this.dibukaKunciPada,
    alasanBukaKunci: alasanBukaKunci.present
        ? alasanBukaKunci.value
        : this.alasanBukaKunci,
    dibuatPada: dibuatPada ?? this.dibuatPada,
    diubahPada: diubahPada ?? this.diubahPada,
  );
  NilaiAsetBulananData copyWithCompanion(NilaiAsetBulananCompanion data) {
    return NilaiAsetBulananData(
      id: data.id.present ? data.id.value : this.id,
      asetId: data.asetId.present ? data.asetId.value : this.asetId,
      bulan: data.bulan.present ? data.bulan.value : this.bulan,
      nilaiSen: data.nilaiSen.present ? data.nilaiSen.value : this.nilaiSen,
      sumber: data.sumber.present ? data.sumber.value : this.sumber,
      idempotensi: data.idempotensi.present
          ? data.idempotensi.value
          : this.idempotensi,
      terkunci: data.terkunci.present ? data.terkunci.value : this.terkunci,
      dikunciPada: data.dikunciPada.present
          ? data.dikunciPada.value
          : this.dikunciPada,
      catatan: data.catatan.present ? data.catatan.value : this.catatan,
      dibukaKunciPada: data.dibukaKunciPada.present
          ? data.dibukaKunciPada.value
          : this.dibukaKunciPada,
      alasanBukaKunci: data.alasanBukaKunci.present
          ? data.alasanBukaKunci.value
          : this.alasanBukaKunci,
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
    return (StringBuffer('NilaiAsetBulananData(')
          ..write('id: $id, ')
          ..write('asetId: $asetId, ')
          ..write('bulan: $bulan, ')
          ..write('nilaiSen: $nilaiSen, ')
          ..write('sumber: $sumber, ')
          ..write('idempotensi: $idempotensi, ')
          ..write('terkunci: $terkunci, ')
          ..write('dikunciPada: $dikunciPada, ')
          ..write('catatan: $catatan, ')
          ..write('dibukaKunciPada: $dibukaKunciPada, ')
          ..write('alasanBukaKunci: $alasanBukaKunci, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    asetId,
    bulan,
    nilaiSen,
    sumber,
    idempotensi,
    terkunci,
    dikunciPada,
    catatan,
    dibukaKunciPada,
    alasanBukaKunci,
    dibuatPada,
    diubahPada,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NilaiAsetBulananData &&
          other.id == this.id &&
          other.asetId == this.asetId &&
          other.bulan == this.bulan &&
          other.nilaiSen == this.nilaiSen &&
          other.sumber == this.sumber &&
          other.idempotensi == this.idempotensi &&
          other.terkunci == this.terkunci &&
          other.dikunciPada == this.dikunciPada &&
          other.catatan == this.catatan &&
          other.dibukaKunciPada == this.dibukaKunciPada &&
          other.alasanBukaKunci == this.alasanBukaKunci &&
          other.dibuatPada == this.dibuatPada &&
          other.diubahPada == this.diubahPada);
}

class NilaiAsetBulananCompanion extends UpdateCompanion<NilaiAsetBulananData> {
  final Value<int> id;
  final Value<int> asetId;
  final Value<String> bulan;
  final Value<int> nilaiSen;
  final Value<String> sumber;
  final Value<String> idempotensi;
  final Value<bool> terkunci;
  final Value<DateTime?> dikunciPada;
  final Value<String?> catatan;
  final Value<DateTime?> dibukaKunciPada;
  final Value<String?> alasanBukaKunci;
  final Value<DateTime> dibuatPada;
  final Value<DateTime> diubahPada;
  const NilaiAsetBulananCompanion({
    this.id = const Value.absent(),
    this.asetId = const Value.absent(),
    this.bulan = const Value.absent(),
    this.nilaiSen = const Value.absent(),
    this.sumber = const Value.absent(),
    this.idempotensi = const Value.absent(),
    this.terkunci = const Value.absent(),
    this.dikunciPada = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibukaKunciPada = const Value.absent(),
    this.alasanBukaKunci = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  });
  NilaiAsetBulananCompanion.insert({
    this.id = const Value.absent(),
    required int asetId,
    required String bulan,
    required int nilaiSen,
    this.sumber = const Value.absent(),
    required String idempotensi,
    this.terkunci = const Value.absent(),
    this.dikunciPada = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibukaKunciPada = const Value.absent(),
    this.alasanBukaKunci = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  }) : asetId = Value(asetId),
       bulan = Value(bulan),
       nilaiSen = Value(nilaiSen),
       idempotensi = Value(idempotensi);
  static Insertable<NilaiAsetBulananData> custom({
    Expression<int>? id,
    Expression<int>? asetId,
    Expression<String>? bulan,
    Expression<int>? nilaiSen,
    Expression<String>? sumber,
    Expression<String>? idempotensi,
    Expression<bool>? terkunci,
    Expression<DateTime>? dikunciPada,
    Expression<String>? catatan,
    Expression<DateTime>? dibukaKunciPada,
    Expression<String>? alasanBukaKunci,
    Expression<DateTime>? dibuatPada,
    Expression<DateTime>? diubahPada,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (asetId != null) 'aset_id': asetId,
      if (bulan != null) 'bulan': bulan,
      if (nilaiSen != null) 'nilai_sen': nilaiSen,
      if (sumber != null) 'sumber': sumber,
      if (idempotensi != null) 'idempotensi': idempotensi,
      if (terkunci != null) 'terkunci': terkunci,
      if (dikunciPada != null) 'dikunci_pada': dikunciPada,
      if (catatan != null) 'catatan': catatan,
      if (dibukaKunciPada != null) 'dibuka_kunci_pada': dibukaKunciPada,
      if (alasanBukaKunci != null) 'alasan_buka_kunci': alasanBukaKunci,
      if (dibuatPada != null) 'dibuat_pada': dibuatPada,
      if (diubahPada != null) 'diubah_pada': diubahPada,
    });
  }

  NilaiAsetBulananCompanion copyWith({
    Value<int>? id,
    Value<int>? asetId,
    Value<String>? bulan,
    Value<int>? nilaiSen,
    Value<String>? sumber,
    Value<String>? idempotensi,
    Value<bool>? terkunci,
    Value<DateTime?>? dikunciPada,
    Value<String?>? catatan,
    Value<DateTime?>? dibukaKunciPada,
    Value<String?>? alasanBukaKunci,
    Value<DateTime>? dibuatPada,
    Value<DateTime>? diubahPada,
  }) {
    return NilaiAsetBulananCompanion(
      id: id ?? this.id,
      asetId: asetId ?? this.asetId,
      bulan: bulan ?? this.bulan,
      nilaiSen: nilaiSen ?? this.nilaiSen,
      sumber: sumber ?? this.sumber,
      idempotensi: idempotensi ?? this.idempotensi,
      terkunci: terkunci ?? this.terkunci,
      dikunciPada: dikunciPada ?? this.dikunciPada,
      catatan: catatan ?? this.catatan,
      dibukaKunciPada: dibukaKunciPada ?? this.dibukaKunciPada,
      alasanBukaKunci: alasanBukaKunci ?? this.alasanBukaKunci,
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
    if (asetId.present) {
      map['aset_id'] = Variable<int>(asetId.value);
    }
    if (bulan.present) {
      map['bulan'] = Variable<String>(bulan.value);
    }
    if (nilaiSen.present) {
      map['nilai_sen'] = Variable<int>(nilaiSen.value);
    }
    if (sumber.present) {
      map['sumber'] = Variable<String>(sumber.value);
    }
    if (idempotensi.present) {
      map['idempotensi'] = Variable<String>(idempotensi.value);
    }
    if (terkunci.present) {
      map['terkunci'] = Variable<bool>(terkunci.value);
    }
    if (dikunciPada.present) {
      map['dikunci_pada'] = Variable<DateTime>(dikunciPada.value);
    }
    if (catatan.present) {
      map['catatan'] = Variable<String>(catatan.value);
    }
    if (dibukaKunciPada.present) {
      map['dibuka_kunci_pada'] = Variable<DateTime>(dibukaKunciPada.value);
    }
    if (alasanBukaKunci.present) {
      map['alasan_buka_kunci'] = Variable<String>(alasanBukaKunci.value);
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
    return (StringBuffer('NilaiAsetBulananCompanion(')
          ..write('id: $id, ')
          ..write('asetId: $asetId, ')
          ..write('bulan: $bulan, ')
          ..write('nilaiSen: $nilaiSen, ')
          ..write('sumber: $sumber, ')
          ..write('idempotensi: $idempotensi, ')
          ..write('terkunci: $terkunci, ')
          ..write('dikunciPada: $dikunciPada, ')
          ..write('catatan: $catatan, ')
          ..write('dibukaKunciPada: $dibukaKunciPada, ')
          ..write('alasanBukaKunci: $alasanBukaKunci, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }
}

class $NilaiKewajibanBulananTable extends NilaiKewajibanBulanan
    with TableInfo<$NilaiKewajibanBulananTable, NilaiKewajibanBulananData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NilaiKewajibanBulananTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _kewajibanIdMeta = const VerificationMeta(
    'kewajibanId',
  );
  @override
  late final GeneratedColumn<int> kewajibanId = GeneratedColumn<int>(
    'kewajiban_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES kewajiban (id)',
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
  static const VerificationMeta _nilaiSenMeta = const VerificationMeta(
    'nilaiSen',
  );
  @override
  late final GeneratedColumn<int> nilaiSen = GeneratedColumn<int>(
    'nilai_sen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sumberMeta = const VerificationMeta('sumber');
  @override
  late final GeneratedColumn<String> sumber = GeneratedColumn<String>(
    'sumber',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _idempotensiMeta = const VerificationMeta(
    'idempotensi',
  );
  @override
  late final GeneratedColumn<String> idempotensi = GeneratedColumn<String>(
    'idempotensi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _terkunciMeta = const VerificationMeta(
    'terkunci',
  );
  @override
  late final GeneratedColumn<bool> terkunci = GeneratedColumn<bool>(
    'terkunci',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("terkunci" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dikunciPadaMeta = const VerificationMeta(
    'dikunciPada',
  );
  @override
  late final GeneratedColumn<DateTime> dikunciPada = GeneratedColumn<DateTime>(
    'dikunci_pada',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  static const VerificationMeta _dibukaKunciPadaMeta = const VerificationMeta(
    'dibukaKunciPada',
  );
  @override
  late final GeneratedColumn<DateTime> dibukaKunciPada =
      GeneratedColumn<DateTime>(
        'dibuka_kunci_pada',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _alasanBukaKunciMeta = const VerificationMeta(
    'alasanBukaKunci',
  );
  @override
  late final GeneratedColumn<String> alasanBukaKunci = GeneratedColumn<String>(
    'alasan_buka_kunci',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    kewajibanId,
    bulan,
    nilaiSen,
    sumber,
    idempotensi,
    terkunci,
    dikunciPada,
    catatan,
    dibukaKunciPada,
    alasanBukaKunci,
    dibuatPada,
    diubahPada,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nilai_kewajiban_bulanan';
  @override
  VerificationContext validateIntegrity(
    Insertable<NilaiKewajibanBulananData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kewajiban_id')) {
      context.handle(
        _kewajibanIdMeta,
        kewajibanId.isAcceptableOrUnknown(
          data['kewajiban_id']!,
          _kewajibanIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_kewajibanIdMeta);
    }
    if (data.containsKey('bulan')) {
      context.handle(
        _bulanMeta,
        bulan.isAcceptableOrUnknown(data['bulan']!, _bulanMeta),
      );
    } else if (isInserting) {
      context.missing(_bulanMeta);
    }
    if (data.containsKey('nilai_sen')) {
      context.handle(
        _nilaiSenMeta,
        nilaiSen.isAcceptableOrUnknown(data['nilai_sen']!, _nilaiSenMeta),
      );
    } else if (isInserting) {
      context.missing(_nilaiSenMeta);
    }
    if (data.containsKey('sumber')) {
      context.handle(
        _sumberMeta,
        sumber.isAcceptableOrUnknown(data['sumber']!, _sumberMeta),
      );
    }
    if (data.containsKey('idempotensi')) {
      context.handle(
        _idempotensiMeta,
        idempotensi.isAcceptableOrUnknown(
          data['idempotensi']!,
          _idempotensiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotensiMeta);
    }
    if (data.containsKey('terkunci')) {
      context.handle(
        _terkunciMeta,
        terkunci.isAcceptableOrUnknown(data['terkunci']!, _terkunciMeta),
      );
    }
    if (data.containsKey('dikunci_pada')) {
      context.handle(
        _dikunciPadaMeta,
        dikunciPada.isAcceptableOrUnknown(
          data['dikunci_pada']!,
          _dikunciPadaMeta,
        ),
      );
    }
    if (data.containsKey('catatan')) {
      context.handle(
        _catatanMeta,
        catatan.isAcceptableOrUnknown(data['catatan']!, _catatanMeta),
      );
    }
    if (data.containsKey('dibuka_kunci_pada')) {
      context.handle(
        _dibukaKunciPadaMeta,
        dibukaKunciPada.isAcceptableOrUnknown(
          data['dibuka_kunci_pada']!,
          _dibukaKunciPadaMeta,
        ),
      );
    }
    if (data.containsKey('alasan_buka_kunci')) {
      context.handle(
        _alasanBukaKunciMeta,
        alasanBukaKunci.isAcceptableOrUnknown(
          data['alasan_buka_kunci']!,
          _alasanBukaKunciMeta,
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
  NilaiKewajibanBulananData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NilaiKewajibanBulananData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kewajibanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kewajiban_id'],
      )!,
      bulan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bulan'],
      )!,
      nilaiSen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nilai_sen'],
      )!,
      sumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sumber'],
      )!,
      idempotensi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotensi'],
      )!,
      terkunci: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}terkunci'],
      )!,
      dikunciPada: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dikunci_pada'],
      ),
      catatan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catatan'],
      ),
      dibukaKunciPada: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dibuka_kunci_pada'],
      ),
      alasanBukaKunci: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alasan_buka_kunci'],
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
  $NilaiKewajibanBulananTable createAlias(String alias) {
    return $NilaiKewajibanBulananTable(attachedDatabase, alias);
  }
}

class NilaiKewajibanBulananData extends DataClass
    implements Insertable<NilaiKewajibanBulananData> {
  final int id;
  final int kewajibanId;
  final String bulan;
  final int nilaiSen;
  final String sumber;

  /// Unik, mis. `kewajiban:3:2026-09`.
  final String idempotensi;
  final bool terkunci;
  final DateTime? dikunciPada;
  final String? catatan;
  final DateTime? dibukaKunciPada;
  final String? alasanBukaKunci;
  final DateTime dibuatPada;
  final DateTime diubahPada;
  const NilaiKewajibanBulananData({
    required this.id,
    required this.kewajibanId,
    required this.bulan,
    required this.nilaiSen,
    required this.sumber,
    required this.idempotensi,
    required this.terkunci,
    this.dikunciPada,
    this.catatan,
    this.dibukaKunciPada,
    this.alasanBukaKunci,
    required this.dibuatPada,
    required this.diubahPada,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kewajiban_id'] = Variable<int>(kewajibanId);
    map['bulan'] = Variable<String>(bulan);
    map['nilai_sen'] = Variable<int>(nilaiSen);
    map['sumber'] = Variable<String>(sumber);
    map['idempotensi'] = Variable<String>(idempotensi);
    map['terkunci'] = Variable<bool>(terkunci);
    if (!nullToAbsent || dikunciPada != null) {
      map['dikunci_pada'] = Variable<DateTime>(dikunciPada);
    }
    if (!nullToAbsent || catatan != null) {
      map['catatan'] = Variable<String>(catatan);
    }
    if (!nullToAbsent || dibukaKunciPada != null) {
      map['dibuka_kunci_pada'] = Variable<DateTime>(dibukaKunciPada);
    }
    if (!nullToAbsent || alasanBukaKunci != null) {
      map['alasan_buka_kunci'] = Variable<String>(alasanBukaKunci);
    }
    map['dibuat_pada'] = Variable<DateTime>(dibuatPada);
    map['diubah_pada'] = Variable<DateTime>(diubahPada);
    return map;
  }

  NilaiKewajibanBulananCompanion toCompanion(bool nullToAbsent) {
    return NilaiKewajibanBulananCompanion(
      id: Value(id),
      kewajibanId: Value(kewajibanId),
      bulan: Value(bulan),
      nilaiSen: Value(nilaiSen),
      sumber: Value(sumber),
      idempotensi: Value(idempotensi),
      terkunci: Value(terkunci),
      dikunciPada: dikunciPada == null && nullToAbsent
          ? const Value.absent()
          : Value(dikunciPada),
      catatan: catatan == null && nullToAbsent
          ? const Value.absent()
          : Value(catatan),
      dibukaKunciPada: dibukaKunciPada == null && nullToAbsent
          ? const Value.absent()
          : Value(dibukaKunciPada),
      alasanBukaKunci: alasanBukaKunci == null && nullToAbsent
          ? const Value.absent()
          : Value(alasanBukaKunci),
      dibuatPada: Value(dibuatPada),
      diubahPada: Value(diubahPada),
    );
  }

  factory NilaiKewajibanBulananData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NilaiKewajibanBulananData(
      id: serializer.fromJson<int>(json['id']),
      kewajibanId: serializer.fromJson<int>(json['kewajibanId']),
      bulan: serializer.fromJson<String>(json['bulan']),
      nilaiSen: serializer.fromJson<int>(json['nilaiSen']),
      sumber: serializer.fromJson<String>(json['sumber']),
      idempotensi: serializer.fromJson<String>(json['idempotensi']),
      terkunci: serializer.fromJson<bool>(json['terkunci']),
      dikunciPada: serializer.fromJson<DateTime?>(json['dikunciPada']),
      catatan: serializer.fromJson<String?>(json['catatan']),
      dibukaKunciPada: serializer.fromJson<DateTime?>(json['dibukaKunciPada']),
      alasanBukaKunci: serializer.fromJson<String?>(json['alasanBukaKunci']),
      dibuatPada: serializer.fromJson<DateTime>(json['dibuatPada']),
      diubahPada: serializer.fromJson<DateTime>(json['diubahPada']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kewajibanId': serializer.toJson<int>(kewajibanId),
      'bulan': serializer.toJson<String>(bulan),
      'nilaiSen': serializer.toJson<int>(nilaiSen),
      'sumber': serializer.toJson<String>(sumber),
      'idempotensi': serializer.toJson<String>(idempotensi),
      'terkunci': serializer.toJson<bool>(terkunci),
      'dikunciPada': serializer.toJson<DateTime?>(dikunciPada),
      'catatan': serializer.toJson<String?>(catatan),
      'dibukaKunciPada': serializer.toJson<DateTime?>(dibukaKunciPada),
      'alasanBukaKunci': serializer.toJson<String?>(alasanBukaKunci),
      'dibuatPada': serializer.toJson<DateTime>(dibuatPada),
      'diubahPada': serializer.toJson<DateTime>(diubahPada),
    };
  }

  NilaiKewajibanBulananData copyWith({
    int? id,
    int? kewajibanId,
    String? bulan,
    int? nilaiSen,
    String? sumber,
    String? idempotensi,
    bool? terkunci,
    Value<DateTime?> dikunciPada = const Value.absent(),
    Value<String?> catatan = const Value.absent(),
    Value<DateTime?> dibukaKunciPada = const Value.absent(),
    Value<String?> alasanBukaKunci = const Value.absent(),
    DateTime? dibuatPada,
    DateTime? diubahPada,
  }) => NilaiKewajibanBulananData(
    id: id ?? this.id,
    kewajibanId: kewajibanId ?? this.kewajibanId,
    bulan: bulan ?? this.bulan,
    nilaiSen: nilaiSen ?? this.nilaiSen,
    sumber: sumber ?? this.sumber,
    idempotensi: idempotensi ?? this.idempotensi,
    terkunci: terkunci ?? this.terkunci,
    dikunciPada: dikunciPada.present ? dikunciPada.value : this.dikunciPada,
    catatan: catatan.present ? catatan.value : this.catatan,
    dibukaKunciPada: dibukaKunciPada.present
        ? dibukaKunciPada.value
        : this.dibukaKunciPada,
    alasanBukaKunci: alasanBukaKunci.present
        ? alasanBukaKunci.value
        : this.alasanBukaKunci,
    dibuatPada: dibuatPada ?? this.dibuatPada,
    diubahPada: diubahPada ?? this.diubahPada,
  );
  NilaiKewajibanBulananData copyWithCompanion(
    NilaiKewajibanBulananCompanion data,
  ) {
    return NilaiKewajibanBulananData(
      id: data.id.present ? data.id.value : this.id,
      kewajibanId: data.kewajibanId.present
          ? data.kewajibanId.value
          : this.kewajibanId,
      bulan: data.bulan.present ? data.bulan.value : this.bulan,
      nilaiSen: data.nilaiSen.present ? data.nilaiSen.value : this.nilaiSen,
      sumber: data.sumber.present ? data.sumber.value : this.sumber,
      idempotensi: data.idempotensi.present
          ? data.idempotensi.value
          : this.idempotensi,
      terkunci: data.terkunci.present ? data.terkunci.value : this.terkunci,
      dikunciPada: data.dikunciPada.present
          ? data.dikunciPada.value
          : this.dikunciPada,
      catatan: data.catatan.present ? data.catatan.value : this.catatan,
      dibukaKunciPada: data.dibukaKunciPada.present
          ? data.dibukaKunciPada.value
          : this.dibukaKunciPada,
      alasanBukaKunci: data.alasanBukaKunci.present
          ? data.alasanBukaKunci.value
          : this.alasanBukaKunci,
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
    return (StringBuffer('NilaiKewajibanBulananData(')
          ..write('id: $id, ')
          ..write('kewajibanId: $kewajibanId, ')
          ..write('bulan: $bulan, ')
          ..write('nilaiSen: $nilaiSen, ')
          ..write('sumber: $sumber, ')
          ..write('idempotensi: $idempotensi, ')
          ..write('terkunci: $terkunci, ')
          ..write('dikunciPada: $dikunciPada, ')
          ..write('catatan: $catatan, ')
          ..write('dibukaKunciPada: $dibukaKunciPada, ')
          ..write('alasanBukaKunci: $alasanBukaKunci, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kewajibanId,
    bulan,
    nilaiSen,
    sumber,
    idempotensi,
    terkunci,
    dikunciPada,
    catatan,
    dibukaKunciPada,
    alasanBukaKunci,
    dibuatPada,
    diubahPada,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NilaiKewajibanBulananData &&
          other.id == this.id &&
          other.kewajibanId == this.kewajibanId &&
          other.bulan == this.bulan &&
          other.nilaiSen == this.nilaiSen &&
          other.sumber == this.sumber &&
          other.idempotensi == this.idempotensi &&
          other.terkunci == this.terkunci &&
          other.dikunciPada == this.dikunciPada &&
          other.catatan == this.catatan &&
          other.dibukaKunciPada == this.dibukaKunciPada &&
          other.alasanBukaKunci == this.alasanBukaKunci &&
          other.dibuatPada == this.dibuatPada &&
          other.diubahPada == this.diubahPada);
}

class NilaiKewajibanBulananCompanion
    extends UpdateCompanion<NilaiKewajibanBulananData> {
  final Value<int> id;
  final Value<int> kewajibanId;
  final Value<String> bulan;
  final Value<int> nilaiSen;
  final Value<String> sumber;
  final Value<String> idempotensi;
  final Value<bool> terkunci;
  final Value<DateTime?> dikunciPada;
  final Value<String?> catatan;
  final Value<DateTime?> dibukaKunciPada;
  final Value<String?> alasanBukaKunci;
  final Value<DateTime> dibuatPada;
  final Value<DateTime> diubahPada;
  const NilaiKewajibanBulananCompanion({
    this.id = const Value.absent(),
    this.kewajibanId = const Value.absent(),
    this.bulan = const Value.absent(),
    this.nilaiSen = const Value.absent(),
    this.sumber = const Value.absent(),
    this.idempotensi = const Value.absent(),
    this.terkunci = const Value.absent(),
    this.dikunciPada = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibukaKunciPada = const Value.absent(),
    this.alasanBukaKunci = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  });
  NilaiKewajibanBulananCompanion.insert({
    this.id = const Value.absent(),
    required int kewajibanId,
    required String bulan,
    required int nilaiSen,
    this.sumber = const Value.absent(),
    required String idempotensi,
    this.terkunci = const Value.absent(),
    this.dikunciPada = const Value.absent(),
    this.catatan = const Value.absent(),
    this.dibukaKunciPada = const Value.absent(),
    this.alasanBukaKunci = const Value.absent(),
    this.dibuatPada = const Value.absent(),
    this.diubahPada = const Value.absent(),
  }) : kewajibanId = Value(kewajibanId),
       bulan = Value(bulan),
       nilaiSen = Value(nilaiSen),
       idempotensi = Value(idempotensi);
  static Insertable<NilaiKewajibanBulananData> custom({
    Expression<int>? id,
    Expression<int>? kewajibanId,
    Expression<String>? bulan,
    Expression<int>? nilaiSen,
    Expression<String>? sumber,
    Expression<String>? idempotensi,
    Expression<bool>? terkunci,
    Expression<DateTime>? dikunciPada,
    Expression<String>? catatan,
    Expression<DateTime>? dibukaKunciPada,
    Expression<String>? alasanBukaKunci,
    Expression<DateTime>? dibuatPada,
    Expression<DateTime>? diubahPada,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kewajibanId != null) 'kewajiban_id': kewajibanId,
      if (bulan != null) 'bulan': bulan,
      if (nilaiSen != null) 'nilai_sen': nilaiSen,
      if (sumber != null) 'sumber': sumber,
      if (idempotensi != null) 'idempotensi': idempotensi,
      if (terkunci != null) 'terkunci': terkunci,
      if (dikunciPada != null) 'dikunci_pada': dikunciPada,
      if (catatan != null) 'catatan': catatan,
      if (dibukaKunciPada != null) 'dibuka_kunci_pada': dibukaKunciPada,
      if (alasanBukaKunci != null) 'alasan_buka_kunci': alasanBukaKunci,
      if (dibuatPada != null) 'dibuat_pada': dibuatPada,
      if (diubahPada != null) 'diubah_pada': diubahPada,
    });
  }

  NilaiKewajibanBulananCompanion copyWith({
    Value<int>? id,
    Value<int>? kewajibanId,
    Value<String>? bulan,
    Value<int>? nilaiSen,
    Value<String>? sumber,
    Value<String>? idempotensi,
    Value<bool>? terkunci,
    Value<DateTime?>? dikunciPada,
    Value<String?>? catatan,
    Value<DateTime?>? dibukaKunciPada,
    Value<String?>? alasanBukaKunci,
    Value<DateTime>? dibuatPada,
    Value<DateTime>? diubahPada,
  }) {
    return NilaiKewajibanBulananCompanion(
      id: id ?? this.id,
      kewajibanId: kewajibanId ?? this.kewajibanId,
      bulan: bulan ?? this.bulan,
      nilaiSen: nilaiSen ?? this.nilaiSen,
      sumber: sumber ?? this.sumber,
      idempotensi: idempotensi ?? this.idempotensi,
      terkunci: terkunci ?? this.terkunci,
      dikunciPada: dikunciPada ?? this.dikunciPada,
      catatan: catatan ?? this.catatan,
      dibukaKunciPada: dibukaKunciPada ?? this.dibukaKunciPada,
      alasanBukaKunci: alasanBukaKunci ?? this.alasanBukaKunci,
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
    if (kewajibanId.present) {
      map['kewajiban_id'] = Variable<int>(kewajibanId.value);
    }
    if (bulan.present) {
      map['bulan'] = Variable<String>(bulan.value);
    }
    if (nilaiSen.present) {
      map['nilai_sen'] = Variable<int>(nilaiSen.value);
    }
    if (sumber.present) {
      map['sumber'] = Variable<String>(sumber.value);
    }
    if (idempotensi.present) {
      map['idempotensi'] = Variable<String>(idempotensi.value);
    }
    if (terkunci.present) {
      map['terkunci'] = Variable<bool>(terkunci.value);
    }
    if (dikunciPada.present) {
      map['dikunci_pada'] = Variable<DateTime>(dikunciPada.value);
    }
    if (catatan.present) {
      map['catatan'] = Variable<String>(catatan.value);
    }
    if (dibukaKunciPada.present) {
      map['dibuka_kunci_pada'] = Variable<DateTime>(dibukaKunciPada.value);
    }
    if (alasanBukaKunci.present) {
      map['alasan_buka_kunci'] = Variable<String>(alasanBukaKunci.value);
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
    return (StringBuffer('NilaiKewajibanBulananCompanion(')
          ..write('id: $id, ')
          ..write('kewajibanId: $kewajibanId, ')
          ..write('bulan: $bulan, ')
          ..write('nilaiSen: $nilaiSen, ')
          ..write('sumber: $sumber, ')
          ..write('idempotensi: $idempotensi, ')
          ..write('terkunci: $terkunci, ')
          ..write('dikunciPada: $dikunciPada, ')
          ..write('catatan: $catatan, ')
          ..write('dibukaKunciPada: $dibukaKunciPada, ')
          ..write('alasanBukaKunci: $alasanBukaKunci, ')
          ..write('dibuatPada: $dibuatPada, ')
          ..write('diubahPada: $diubahPada')
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
  late final $KategoriTransaksiTable kategoriTransaksi =
      $KategoriTransaksiTable(this);
  late final $TransaksiTable transaksi = $TransaksiTable(this);
  late final $AnggaranBulananTable anggaranBulanan = $AnggaranBulananTable(
    this,
  );
  late final $LanggananTable langganan = $LanggananTable(this);
  late final $AsetTable aset = $AsetTable(this);
  late final $KewajibanTable kewajiban = $KewajibanTable(this);
  late final $NilaiAsetBulananTable nilaiAsetBulanan = $NilaiAsetBulananTable(
    this,
  );
  late final $NilaiKewajibanBulananTable nilaiKewajibanBulanan =
      $NilaiKewajibanBulananTable(this);
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
    kategoriTransaksi,
    transaksi,
    anggaranBulanan,
    langganan,
    aset,
    kewajiban,
    nilaiAsetBulanan,
    nilaiKewajibanBulanan,
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

  static MultiTypedResultKey<$TransaksiTable, List<TransaksiData>>
  _transaksiRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transaksi,
    aliasName: 'tagihan__id__transaksi__tagihan_id',
  );

  $$TransaksiTableProcessedTableManager get transaksiRefs {
    final manager = $$TransaksiTableTableManager(
      $_db,
      $_db.transaksi,
    ).filter((f) => f.tagihanId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transaksiRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LanggananTable, List<LanggananData>>
  _langgananRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.langganan,
    aliasName: 'tagihan__id__langganan__tagihan_id',
  );

  $$LanggananTableProcessedTableManager get langgananRefs {
    final manager = $$LanggananTableTableManager(
      $_db,
      $_db.langganan,
    ).filter((f) => f.tagihanId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_langgananRefsTable($_db));
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

  Expression<bool> transaksiRefs(
    Expression<bool> Function($$TransaksiTableFilterComposer f) f,
  ) {
    final $$TransaksiTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transaksi,
      getReferencedColumn: (t) => t.tagihanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransaksiTableFilterComposer(
            $db: $db,
            $table: $db.transaksi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> langgananRefs(
    Expression<bool> Function($$LanggananTableFilterComposer f) f,
  ) {
    final $$LanggananTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.langganan,
      getReferencedColumn: (t) => t.tagihanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LanggananTableFilterComposer(
            $db: $db,
            $table: $db.langganan,
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

  Expression<T> transaksiRefs<T extends Object>(
    Expression<T> Function($$TransaksiTableAnnotationComposer a) f,
  ) {
    final $$TransaksiTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transaksi,
      getReferencedColumn: (t) => t.tagihanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransaksiTableAnnotationComposer(
            $db: $db,
            $table: $db.transaksi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> langgananRefs<T extends Object>(
    Expression<T> Function($$LanggananTableAnnotationComposer a) f,
  ) {
    final $$LanggananTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.langganan,
      getReferencedColumn: (t) => t.tagihanId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LanggananTableAnnotationComposer(
            $db: $db,
            $table: $db.langganan,
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
          PrefetchHooks Function({
            bool kategoriId,
            bool riwayatPembayaranRefs,
            bool transaksiRefs,
            bool langgananRefs,
          })
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
              ({
                kategoriId = false,
                riwayatPembayaranRefs = false,
                transaksiRefs = false,
                langgananRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (riwayatPembayaranRefs) db.riwayatPembayaran,
                    if (transaksiRefs) db.transaksi,
                    if (langgananRefs) db.langganan,
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
                      if (transaksiRefs)
                        await $_getPrefetchedData<
                          TagihanData,
                          $TagihanTable,
                          TransaksiData
                        >(
                          currentTable: table,
                          referencedTable: $$TagihanTableReferences
                              ._transaksiRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TagihanTableReferences(
                                db,
                                table,
                                p0,
                              ).transaksiRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tagihanId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (langgananRefs)
                        await $_getPrefetchedData<
                          TagihanData,
                          $TagihanTable,
                          LanggananData
                        >(
                          currentTable: table,
                          referencedTable: $$TagihanTableReferences
                              ._langgananRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TagihanTableReferences(
                                db,
                                table,
                                p0,
                              ).langgananRefs,
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
      PrefetchHooks Function({
        bool kategoriId,
        bool riwayatPembayaranRefs,
        bool transaksiRefs,
        bool langgananRefs,
      })
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
typedef $$KategoriTransaksiTableCreateCompanionBuilder =
    KategoriTransaksiCompanion Function({
      Value<int> id,
      required String kode,
      Value<String?> indukKode,
      required String nama,
      Value<String> jenis,
      Value<String> ikon,
      Value<String> warna,
      Value<int> urutan,
      Value<String> sifatArus,
      Value<bool> bawaanSistem,
      Value<bool> arsip,
      Value<DateTime> dibuatPada,
      Value<DateTime> diubahPada,
    });
typedef $$KategoriTransaksiTableUpdateCompanionBuilder =
    KategoriTransaksiCompanion Function({
      Value<int> id,
      Value<String> kode,
      Value<String?> indukKode,
      Value<String> nama,
      Value<String> jenis,
      Value<String> ikon,
      Value<String> warna,
      Value<int> urutan,
      Value<String> sifatArus,
      Value<bool> bawaanSistem,
      Value<bool> arsip,
      Value<DateTime> dibuatPada,
      Value<DateTime> diubahPada,
    });

final class $$KategoriTransaksiTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $KategoriTransaksiTable,
          KategoriTransaksiData
        > {
  $$KategoriTransaksiTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TransaksiTable, List<TransaksiData>>
  _transaksiRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transaksi,
    aliasName: 'kategori_transaksi__id__transaksi__kategori_id',
  );

  $$TransaksiTableProcessedTableManager get transaksiRefs {
    final manager = $$TransaksiTableTableManager(
      $_db,
      $_db.transaksi,
    ).filter((f) => f.kategoriId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transaksiRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LanggananTable, List<LanggananData>>
  _langgananRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.langganan,
    aliasName: 'kategori_transaksi__id__langganan__kategori_id',
  );

  $$LanggananTableProcessedTableManager get langgananRefs {
    final manager = $$LanggananTableTableManager(
      $_db,
      $_db.langganan,
    ).filter((f) => f.kategoriId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_langgananRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$KategoriTransaksiTableFilterComposer
    extends Composer<_$AppDatabase, $KategoriTransaksiTable> {
  $$KategoriTransaksiTableFilterComposer({
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

  ColumnFilters<String> get kode => $composableBuilder(
    column: $table.kode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get indukKode => $composableBuilder(
    column: $table.indukKode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jenis => $composableBuilder(
    column: $table.jenis,
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

  ColumnFilters<String> get sifatArus => $composableBuilder(
    column: $table.sifatArus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get bawaanSistem => $composableBuilder(
    column: $table.bawaanSistem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get arsip => $composableBuilder(
    column: $table.arsip,
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

  Expression<bool> transaksiRefs(
    Expression<bool> Function($$TransaksiTableFilterComposer f) f,
  ) {
    final $$TransaksiTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transaksi,
      getReferencedColumn: (t) => t.kategoriId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransaksiTableFilterComposer(
            $db: $db,
            $table: $db.transaksi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> langgananRefs(
    Expression<bool> Function($$LanggananTableFilterComposer f) f,
  ) {
    final $$LanggananTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.langganan,
      getReferencedColumn: (t) => t.kategoriId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LanggananTableFilterComposer(
            $db: $db,
            $table: $db.langganan,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KategoriTransaksiTableOrderingComposer
    extends Composer<_$AppDatabase, $KategoriTransaksiTable> {
  $$KategoriTransaksiTableOrderingComposer({
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

  ColumnOrderings<String> get kode => $composableBuilder(
    column: $table.kode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get indukKode => $composableBuilder(
    column: $table.indukKode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jenis => $composableBuilder(
    column: $table.jenis,
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

  ColumnOrderings<String> get sifatArus => $composableBuilder(
    column: $table.sifatArus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get bawaanSistem => $composableBuilder(
    column: $table.bawaanSistem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get arsip => $composableBuilder(
    column: $table.arsip,
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
}

class $$KategoriTransaksiTableAnnotationComposer
    extends Composer<_$AppDatabase, $KategoriTransaksiTable> {
  $$KategoriTransaksiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kode =>
      $composableBuilder(column: $table.kode, builder: (column) => column);

  GeneratedColumn<String> get indukKode =>
      $composableBuilder(column: $table.indukKode, builder: (column) => column);

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<String> get jenis =>
      $composableBuilder(column: $table.jenis, builder: (column) => column);

  GeneratedColumn<String> get ikon =>
      $composableBuilder(column: $table.ikon, builder: (column) => column);

  GeneratedColumn<String> get warna =>
      $composableBuilder(column: $table.warna, builder: (column) => column);

  GeneratedColumn<int> get urutan =>
      $composableBuilder(column: $table.urutan, builder: (column) => column);

  GeneratedColumn<String> get sifatArus =>
      $composableBuilder(column: $table.sifatArus, builder: (column) => column);

  GeneratedColumn<bool> get bawaanSistem => $composableBuilder(
    column: $table.bawaanSistem,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get arsip =>
      $composableBuilder(column: $table.arsip, builder: (column) => column);

  GeneratedColumn<DateTime> get dibuatPada => $composableBuilder(
    column: $table.dibuatPada,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get diubahPada => $composableBuilder(
    column: $table.diubahPada,
    builder: (column) => column,
  );

  Expression<T> transaksiRefs<T extends Object>(
    Expression<T> Function($$TransaksiTableAnnotationComposer a) f,
  ) {
    final $$TransaksiTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transaksi,
      getReferencedColumn: (t) => t.kategoriId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransaksiTableAnnotationComposer(
            $db: $db,
            $table: $db.transaksi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> langgananRefs<T extends Object>(
    Expression<T> Function($$LanggananTableAnnotationComposer a) f,
  ) {
    final $$LanggananTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.langganan,
      getReferencedColumn: (t) => t.kategoriId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LanggananTableAnnotationComposer(
            $db: $db,
            $table: $db.langganan,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KategoriTransaksiTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KategoriTransaksiTable,
          KategoriTransaksiData,
          $$KategoriTransaksiTableFilterComposer,
          $$KategoriTransaksiTableOrderingComposer,
          $$KategoriTransaksiTableAnnotationComposer,
          $$KategoriTransaksiTableCreateCompanionBuilder,
          $$KategoriTransaksiTableUpdateCompanionBuilder,
          (KategoriTransaksiData, $$KategoriTransaksiTableReferences),
          KategoriTransaksiData,
          PrefetchHooks Function({bool transaksiRefs, bool langgananRefs})
        > {
  $$KategoriTransaksiTableTableManager(
    _$AppDatabase db,
    $KategoriTransaksiTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KategoriTransaksiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KategoriTransaksiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KategoriTransaksiTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kode = const Value.absent(),
                Value<String?> indukKode = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<String> jenis = const Value.absent(),
                Value<String> ikon = const Value.absent(),
                Value<String> warna = const Value.absent(),
                Value<int> urutan = const Value.absent(),
                Value<String> sifatArus = const Value.absent(),
                Value<bool> bawaanSistem = const Value.absent(),
                Value<bool> arsip = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => KategoriTransaksiCompanion(
                id: id,
                kode: kode,
                indukKode: indukKode,
                nama: nama,
                jenis: jenis,
                ikon: ikon,
                warna: warna,
                urutan: urutan,
                sifatArus: sifatArus,
                bawaanSistem: bawaanSistem,
                arsip: arsip,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kode,
                Value<String?> indukKode = const Value.absent(),
                required String nama,
                Value<String> jenis = const Value.absent(),
                Value<String> ikon = const Value.absent(),
                Value<String> warna = const Value.absent(),
                Value<int> urutan = const Value.absent(),
                Value<String> sifatArus = const Value.absent(),
                Value<bool> bawaanSistem = const Value.absent(),
                Value<bool> arsip = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => KategoriTransaksiCompanion.insert(
                id: id,
                kode: kode,
                indukKode: indukKode,
                nama: nama,
                jenis: jenis,
                ikon: ikon,
                warna: warna,
                urutan: urutan,
                sifatArus: sifatArus,
                bawaanSistem: bawaanSistem,
                arsip: arsip,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KategoriTransaksiTable, KategoriTransaksiData>(
                    table,
                  ),
                  $$KategoriTransaksiTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({transaksiRefs = false, langgananRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transaksiRefs) db.transaksi,
                    if (langgananRefs) db.langganan,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transaksiRefs)
                        await $_getPrefetchedData<
                          KategoriTransaksiData,
                          $KategoriTransaksiTable,
                          TransaksiData
                        >(
                          currentTable: table,
                          referencedTable: $$KategoriTransaksiTableReferences
                              ._transaksiRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$KategoriTransaksiTableReferences(
                                db,
                                table,
                                p0,
                              ).transaksiRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.kategoriId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (langgananRefs)
                        await $_getPrefetchedData<
                          KategoriTransaksiData,
                          $KategoriTransaksiTable,
                          LanggananData
                        >(
                          currentTable: table,
                          referencedTable: $$KategoriTransaksiTableReferences
                              ._langgananRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$KategoriTransaksiTableReferences(
                                db,
                                table,
                                p0,
                              ).langgananRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.kategoriId == item.id,
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

typedef $$KategoriTransaksiTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KategoriTransaksiTable,
      KategoriTransaksiData,
      $$KategoriTransaksiTableFilterComposer,
      $$KategoriTransaksiTableOrderingComposer,
      $$KategoriTransaksiTableAnnotationComposer,
      $$KategoriTransaksiTableCreateCompanionBuilder,
      $$KategoriTransaksiTableUpdateCompanionBuilder,
      (KategoriTransaksiData, $$KategoriTransaksiTableReferences),
      KategoriTransaksiData,
      PrefetchHooks Function({bool transaksiRefs, bool langgananRefs})
    >;
typedef $$TransaksiTableCreateCompanionBuilder = TransaksiCompanion Function({
  Value<int> id,
  required String idTransaksi,
  Value<String> jenis,
  required DateTime tanggal,
  required int jumlahSen,
  Value<String> kodeMataUang,
  Value<int?> kategoriId,
  Value<String?> catatan,
  Value<String> sumber,
  Value<int?> tagihanId,
  Value<String?> periodeTagihan,
  Value<DateTime> dibuatPada,
  Value<DateTime> diubahPada,
});
typedef $$TransaksiTableUpdateCompanionBuilder = TransaksiCompanion Function({
  Value<int> id,
  Value<String> idTransaksi,
  Value<String> jenis,
  Value<DateTime> tanggal,
  Value<int> jumlahSen,
  Value<String> kodeMataUang,
  Value<int?> kategoriId,
  Value<String?> catatan,
  Value<String> sumber,
  Value<int?> tagihanId,
  Value<String?> periodeTagihan,
  Value<DateTime> dibuatPada,
  Value<DateTime> diubahPada,
});

final class $$TransaksiTableReferences
    extends BaseReferences<_$AppDatabase, $TransaksiTable, TransaksiData> {
  $$TransaksiTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $KategoriTransaksiTable _kategoriIdTable(_$AppDatabase db) => db
      .kategoriTransaksi
      .createAlias('transaksi__kategori_id__kategori_transaksi__id');

  $$KategoriTransaksiTableProcessedTableManager? get kategoriId {
    final $_column = $_itemColumn<int>('kategori_id');
    if ($_column == null) return null;
    final manager = $$KategoriTransaksiTableTableManager(
      $_db,
      $_db.kategoriTransaksi,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_kategoriIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagihanTable _tagihanIdTable(_$AppDatabase db) =>
      db.tagihan.createAlias('transaksi__tagihan_id__tagihan__id');

  $$TagihanTableProcessedTableManager? get tagihanId {
    final $_column = $_itemColumn<int>('tagihan_id');
    if ($_column == null) return null;
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

class $$TransaksiTableFilterComposer
    extends Composer<_$AppDatabase, $TransaksiTable> {
  $$TransaksiTableFilterComposer({
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

  ColumnFilters<String> get idTransaksi => $composableBuilder(
    column: $table.idTransaksi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jenis => $composableBuilder(
    column: $table.jenis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tanggal => $composableBuilder(
    column: $table.tanggal,
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

  ColumnFilters<String> get catatan => $composableBuilder(
    column: $table.catatan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sumber => $composableBuilder(
    column: $table.sumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodeTagihan => $composableBuilder(
    column: $table.periodeTagihan,
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

  $$KategoriTransaksiTableFilterComposer get kategoriId {
    final $$KategoriTransaksiTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kategoriId,
      referencedTable: $db.kategoriTransaksi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KategoriTransaksiTableFilterComposer(
            $db: $db,
            $table: $db.kategoriTransaksi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

class $$TransaksiTableOrderingComposer
    extends Composer<_$AppDatabase, $TransaksiTable> {
  $$TransaksiTableOrderingComposer({
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

  ColumnOrderings<String> get idTransaksi => $composableBuilder(
    column: $table.idTransaksi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jenis => $composableBuilder(
    column: $table.jenis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tanggal => $composableBuilder(
    column: $table.tanggal,
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

  ColumnOrderings<String> get catatan => $composableBuilder(
    column: $table.catatan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sumber => $composableBuilder(
    column: $table.sumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodeTagihan => $composableBuilder(
    column: $table.periodeTagihan,
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

  $$KategoriTransaksiTableOrderingComposer get kategoriId {
    final $$KategoriTransaksiTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kategoriId,
      referencedTable: $db.kategoriTransaksi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KategoriTransaksiTableOrderingComposer(
            $db: $db,
            $table: $db.kategoriTransaksi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

class $$TransaksiTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransaksiTable> {
  $$TransaksiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get idTransaksi => $composableBuilder(
    column: $table.idTransaksi,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jenis =>
      $composableBuilder(column: $table.jenis, builder: (column) => column);

  GeneratedColumn<DateTime> get tanggal =>
      $composableBuilder(column: $table.tanggal, builder: (column) => column);

  GeneratedColumn<int> get jumlahSen =>
      $composableBuilder(column: $table.jumlahSen, builder: (column) => column);

  GeneratedColumn<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get catatan =>
      $composableBuilder(column: $table.catatan, builder: (column) => column);

  GeneratedColumn<String> get sumber =>
      $composableBuilder(column: $table.sumber, builder: (column) => column);

  GeneratedColumn<String> get periodeTagihan => $composableBuilder(
    column: $table.periodeTagihan,
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

  $$KategoriTransaksiTableAnnotationComposer get kategoriId {
    final $$KategoriTransaksiTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.kategoriId,
          referencedTable: $db.kategoriTransaksi,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$KategoriTransaksiTableAnnotationComposer(
                $db: $db,
                $table: $db.kategoriTransaksi,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

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

class $$TransaksiTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransaksiTable,
          TransaksiData,
          $$TransaksiTableFilterComposer,
          $$TransaksiTableOrderingComposer,
          $$TransaksiTableAnnotationComposer,
          $$TransaksiTableCreateCompanionBuilder,
          $$TransaksiTableUpdateCompanionBuilder,
          (TransaksiData, $$TransaksiTableReferences),
          TransaksiData,
          PrefetchHooks Function({bool kategoriId, bool tagihanId})
        > {
  $$TransaksiTableTableManager(_$AppDatabase db, $TransaksiTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransaksiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransaksiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransaksiTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> idTransaksi = const Value.absent(),
                Value<String> jenis = const Value.absent(),
                Value<DateTime> tanggal = const Value.absent(),
                Value<int> jumlahSen = const Value.absent(),
                Value<String> kodeMataUang = const Value.absent(),
                Value<int?> kategoriId = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<String> sumber = const Value.absent(),
                Value<int?> tagihanId = const Value.absent(),
                Value<String?> periodeTagihan = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => TransaksiCompanion(
                id: id,
                idTransaksi: idTransaksi,
                jenis: jenis,
                tanggal: tanggal,
                jumlahSen: jumlahSen,
                kodeMataUang: kodeMataUang,
                kategoriId: kategoriId,
                catatan: catatan,
                sumber: sumber,
                tagihanId: tagihanId,
                periodeTagihan: periodeTagihan,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String idTransaksi,
                Value<String> jenis = const Value.absent(),
                required DateTime tanggal,
                required int jumlahSen,
                Value<String> kodeMataUang = const Value.absent(),
                Value<int?> kategoriId = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<String> sumber = const Value.absent(),
                Value<int?> tagihanId = const Value.absent(),
                Value<String?> periodeTagihan = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => TransaksiCompanion.insert(
                id: id,
                idTransaksi: idTransaksi,
                jenis: jenis,
                tanggal: tanggal,
                jumlahSen: jumlahSen,
                kodeMataUang: kodeMataUang,
                kategoriId: kategoriId,
                catatan: catatan,
                sumber: sumber,
                tagihanId: tagihanId,
                periodeTagihan: periodeTagihan,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransaksiTable, TransaksiData>(table),
                  $$TransaksiTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({kategoriId = false, tagihanId = false}) {
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
                    if (kategoriId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.kategoriId,
                        referencedTable: $$TransaksiTableReferences
                            ._kategoriIdTable(db),
                        referencedColumn: $$TransaksiTableReferences
                            ._kategoriIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (tagihanId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagihanId,
                        referencedTable: $$TransaksiTableReferences
                            ._tagihanIdTable(db),
                        referencedColumn: $$TransaksiTableReferences
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

typedef $$TransaksiTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransaksiTable,
      TransaksiData,
      $$TransaksiTableFilterComposer,
      $$TransaksiTableOrderingComposer,
      $$TransaksiTableAnnotationComposer,
      $$TransaksiTableCreateCompanionBuilder,
      $$TransaksiTableUpdateCompanionBuilder,
      (TransaksiData, $$TransaksiTableReferences),
      TransaksiData,
      PrefetchHooks Function({bool kategoriId, bool tagihanId})
    >;
typedef $$AnggaranBulananTableCreateCompanionBuilder =
    AnggaranBulananCompanion Function({
      Value<int> id,
      required String periode,
      Value<int> kategoriId,
      Value<int> batasSen,
      Value<String> ambangPeringatan,
      Value<bool> terkunci,
      Value<DateTime?> dikunciPada,
      Value<String?> catatan,
      Value<DateTime> dibuatPada,
      Value<DateTime> diubahPada,
    });
typedef $$AnggaranBulananTableUpdateCompanionBuilder =
    AnggaranBulananCompanion Function({
      Value<int> id,
      Value<String> periode,
      Value<int> kategoriId,
      Value<int> batasSen,
      Value<String> ambangPeringatan,
      Value<bool> terkunci,
      Value<DateTime?> dikunciPada,
      Value<String?> catatan,
      Value<DateTime> dibuatPada,
      Value<DateTime> diubahPada,
    });

class $$AnggaranBulananTableFilterComposer
    extends Composer<_$AppDatabase, $AnggaranBulananTable> {
  $$AnggaranBulananTableFilterComposer({
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

  ColumnFilters<String> get periode => $composableBuilder(
    column: $table.periode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kategoriId => $composableBuilder(
    column: $table.kategoriId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batasSen => $composableBuilder(
    column: $table.batasSen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ambangPeringatan => $composableBuilder(
    column: $table.ambangPeringatan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get terkunci => $composableBuilder(
    column: $table.terkunci,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dikunciPada => $composableBuilder(
    column: $table.dikunciPada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catatan => $composableBuilder(
    column: $table.catatan,
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
}

class $$AnggaranBulananTableOrderingComposer
    extends Composer<_$AppDatabase, $AnggaranBulananTable> {
  $$AnggaranBulananTableOrderingComposer({
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

  ColumnOrderings<String> get periode => $composableBuilder(
    column: $table.periode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kategoriId => $composableBuilder(
    column: $table.kategoriId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batasSen => $composableBuilder(
    column: $table.batasSen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ambangPeringatan => $composableBuilder(
    column: $table.ambangPeringatan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get terkunci => $composableBuilder(
    column: $table.terkunci,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dikunciPada => $composableBuilder(
    column: $table.dikunciPada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catatan => $composableBuilder(
    column: $table.catatan,
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
}

class $$AnggaranBulananTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnggaranBulananTable> {
  $$AnggaranBulananTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get periode =>
      $composableBuilder(column: $table.periode, builder: (column) => column);

  GeneratedColumn<int> get kategoriId => $composableBuilder(
    column: $table.kategoriId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get batasSen =>
      $composableBuilder(column: $table.batasSen, builder: (column) => column);

  GeneratedColumn<String> get ambangPeringatan => $composableBuilder(
    column: $table.ambangPeringatan,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get terkunci =>
      $composableBuilder(column: $table.terkunci, builder: (column) => column);

  GeneratedColumn<DateTime> get dikunciPada => $composableBuilder(
    column: $table.dikunciPada,
    builder: (column) => column,
  );

  GeneratedColumn<String> get catatan =>
      $composableBuilder(column: $table.catatan, builder: (column) => column);

  GeneratedColumn<DateTime> get dibuatPada => $composableBuilder(
    column: $table.dibuatPada,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get diubahPada => $composableBuilder(
    column: $table.diubahPada,
    builder: (column) => column,
  );
}

class $$AnggaranBulananTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnggaranBulananTable,
          AnggaranBulananData,
          $$AnggaranBulananTableFilterComposer,
          $$AnggaranBulananTableOrderingComposer,
          $$AnggaranBulananTableAnnotationComposer,
          $$AnggaranBulananTableCreateCompanionBuilder,
          $$AnggaranBulananTableUpdateCompanionBuilder,
          (
            AnggaranBulananData,
            BaseReferences<
              _$AppDatabase,
              $AnggaranBulananTable,
              AnggaranBulananData
            >,
          ),
          AnggaranBulananData,
          PrefetchHooks Function()
        > {
  $$AnggaranBulananTableTableManager(
    _$AppDatabase db,
    $AnggaranBulananTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnggaranBulananTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnggaranBulananTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnggaranBulananTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> periode = const Value.absent(),
                Value<int> kategoriId = const Value.absent(),
                Value<int> batasSen = const Value.absent(),
                Value<String> ambangPeringatan = const Value.absent(),
                Value<bool> terkunci = const Value.absent(),
                Value<DateTime?> dikunciPada = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => AnggaranBulananCompanion(
                id: id,
                periode: periode,
                kategoriId: kategoriId,
                batasSen: batasSen,
                ambangPeringatan: ambangPeringatan,
                terkunci: terkunci,
                dikunciPada: dikunciPada,
                catatan: catatan,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String periode,
                Value<int> kategoriId = const Value.absent(),
                Value<int> batasSen = const Value.absent(),
                Value<String> ambangPeringatan = const Value.absent(),
                Value<bool> terkunci = const Value.absent(),
                Value<DateTime?> dikunciPada = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => AnggaranBulananCompanion.insert(
                id: id,
                periode: periode,
                kategoriId: kategoriId,
                batasSen: batasSen,
                ambangPeringatan: ambangPeringatan,
                terkunci: terkunci,
                dikunciPada: dikunciPada,
                catatan: catatan,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnggaranBulananTable, AnggaranBulananData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $AnggaranBulananTable,
                    AnggaranBulananData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnggaranBulananTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnggaranBulananTable,
      AnggaranBulananData,
      $$AnggaranBulananTableFilterComposer,
      $$AnggaranBulananTableOrderingComposer,
      $$AnggaranBulananTableAnnotationComposer,
      $$AnggaranBulananTableCreateCompanionBuilder,
      $$AnggaranBulananTableUpdateCompanionBuilder,
      (
        AnggaranBulananData,
        BaseReferences<
          _$AppDatabase,
          $AnggaranBulananTable,
          AnggaranBulananData
        >,
      ),
      AnggaranBulananData,
      PrefetchHooks Function()
    >;
typedef $$LanggananTableCreateCompanionBuilder = LanggananCompanion Function({
  Value<int> id,
  required String idLangganan,
  Value<int?> tagihanId,
  required String nama,
  Value<int> nominalSen,
  Value<String> kodeMataUang,
  Value<int?> kategoriId,
  Value<String> siklus,
  required DateTime tanggalMulai,
  Value<bool> perpanjangOtomatis,
  Value<String> status,
  Value<DateTime?> pauseSejak,
  Value<DateTime?> pauseSampai,
  Value<String?> metodeBayar,
  Value<String?> tautanBayar,
  Value<DateTime?> terakhirDipakaiPada,
  Value<String?> catatan,
  Value<DateTime> dibuatPada,
  Value<DateTime> diubahPada,
});
typedef $$LanggananTableUpdateCompanionBuilder = LanggananCompanion Function({
  Value<int> id,
  Value<String> idLangganan,
  Value<int?> tagihanId,
  Value<String> nama,
  Value<int> nominalSen,
  Value<String> kodeMataUang,
  Value<int?> kategoriId,
  Value<String> siklus,
  Value<DateTime> tanggalMulai,
  Value<bool> perpanjangOtomatis,
  Value<String> status,
  Value<DateTime?> pauseSejak,
  Value<DateTime?> pauseSampai,
  Value<String?> metodeBayar,
  Value<String?> tautanBayar,
  Value<DateTime?> terakhirDipakaiPada,
  Value<String?> catatan,
  Value<DateTime> dibuatPada,
  Value<DateTime> diubahPada,
});

final class $$LanggananTableReferences
    extends BaseReferences<_$AppDatabase, $LanggananTable, LanggananData> {
  $$LanggananTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TagihanTable _tagihanIdTable(_$AppDatabase db) =>
      db.tagihan.createAlias('langganan__tagihan_id__tagihan__id');

  $$TagihanTableProcessedTableManager? get tagihanId {
    final $_column = $_itemColumn<int>('tagihan_id');
    if ($_column == null) return null;
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

  static $KategoriTransaksiTable _kategoriIdTable(_$AppDatabase db) => db
      .kategoriTransaksi
      .createAlias('langganan__kategori_id__kategori_transaksi__id');

  $$KategoriTransaksiTableProcessedTableManager? get kategoriId {
    final $_column = $_itemColumn<int>('kategori_id');
    if ($_column == null) return null;
    final manager = $$KategoriTransaksiTableTableManager(
      $_db,
      $_db.kategoriTransaksi,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_kategoriIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LanggananTableFilterComposer
    extends Composer<_$AppDatabase, $LanggananTable> {
  $$LanggananTableFilterComposer({
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

  ColumnFilters<String> get idLangganan => $composableBuilder(
    column: $table.idLangganan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nominalSen => $composableBuilder(
    column: $table.nominalSen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get siklus => $composableBuilder(
    column: $table.siklus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tanggalMulai => $composableBuilder(
    column: $table.tanggalMulai,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get perpanjangOtomatis => $composableBuilder(
    column: $table.perpanjangOtomatis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pauseSejak => $composableBuilder(
    column: $table.pauseSejak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pauseSampai => $composableBuilder(
    column: $table.pauseSampai,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metodeBayar => $composableBuilder(
    column: $table.metodeBayar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tautanBayar => $composableBuilder(
    column: $table.tautanBayar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get terakhirDipakaiPada => $composableBuilder(
    column: $table.terakhirDipakaiPada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catatan => $composableBuilder(
    column: $table.catatan,
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

  $$KategoriTransaksiTableFilterComposer get kategoriId {
    final $$KategoriTransaksiTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kategoriId,
      referencedTable: $db.kategoriTransaksi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KategoriTransaksiTableFilterComposer(
            $db: $db,
            $table: $db.kategoriTransaksi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LanggananTableOrderingComposer
    extends Composer<_$AppDatabase, $LanggananTable> {
  $$LanggananTableOrderingComposer({
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

  ColumnOrderings<String> get idLangganan => $composableBuilder(
    column: $table.idLangganan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nominalSen => $composableBuilder(
    column: $table.nominalSen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get siklus => $composableBuilder(
    column: $table.siklus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tanggalMulai => $composableBuilder(
    column: $table.tanggalMulai,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get perpanjangOtomatis => $composableBuilder(
    column: $table.perpanjangOtomatis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pauseSejak => $composableBuilder(
    column: $table.pauseSejak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pauseSampai => $composableBuilder(
    column: $table.pauseSampai,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metodeBayar => $composableBuilder(
    column: $table.metodeBayar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tautanBayar => $composableBuilder(
    column: $table.tautanBayar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get terakhirDipakaiPada => $composableBuilder(
    column: $table.terakhirDipakaiPada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catatan => $composableBuilder(
    column: $table.catatan,
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

  $$KategoriTransaksiTableOrderingComposer get kategoriId {
    final $$KategoriTransaksiTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kategoriId,
      referencedTable: $db.kategoriTransaksi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KategoriTransaksiTableOrderingComposer(
            $db: $db,
            $table: $db.kategoriTransaksi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LanggananTableAnnotationComposer
    extends Composer<_$AppDatabase, $LanggananTable> {
  $$LanggananTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get idLangganan => $composableBuilder(
    column: $table.idLangganan,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<int> get nominalSen => $composableBuilder(
    column: $table.nominalSen,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => column,
  );

  GeneratedColumn<String> get siklus =>
      $composableBuilder(column: $table.siklus, builder: (column) => column);

  GeneratedColumn<DateTime> get tanggalMulai => $composableBuilder(
    column: $table.tanggalMulai,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get perpanjangOtomatis => $composableBuilder(
    column: $table.perpanjangOtomatis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get pauseSejak => $composableBuilder(
    column: $table.pauseSejak,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get pauseSampai => $composableBuilder(
    column: $table.pauseSampai,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metodeBayar => $composableBuilder(
    column: $table.metodeBayar,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tautanBayar => $composableBuilder(
    column: $table.tautanBayar,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get terakhirDipakaiPada => $composableBuilder(
    column: $table.terakhirDipakaiPada,
    builder: (column) => column,
  );

  GeneratedColumn<String> get catatan =>
      $composableBuilder(column: $table.catatan, builder: (column) => column);

  GeneratedColumn<DateTime> get dibuatPada => $composableBuilder(
    column: $table.dibuatPada,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get diubahPada => $composableBuilder(
    column: $table.diubahPada,
    builder: (column) => column,
  );

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

  $$KategoriTransaksiTableAnnotationComposer get kategoriId {
    final $$KategoriTransaksiTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.kategoriId,
          referencedTable: $db.kategoriTransaksi,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$KategoriTransaksiTableAnnotationComposer(
                $db: $db,
                $table: $db.kategoriTransaksi,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LanggananTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LanggananTable,
          LanggananData,
          $$LanggananTableFilterComposer,
          $$LanggananTableOrderingComposer,
          $$LanggananTableAnnotationComposer,
          $$LanggananTableCreateCompanionBuilder,
          $$LanggananTableUpdateCompanionBuilder,
          (LanggananData, $$LanggananTableReferences),
          LanggananData,
          PrefetchHooks Function({bool tagihanId, bool kategoriId})
        > {
  $$LanggananTableTableManager(_$AppDatabase db, $LanggananTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LanggananTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LanggananTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LanggananTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> idLangganan = const Value.absent(),
                Value<int?> tagihanId = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<int> nominalSen = const Value.absent(),
                Value<String> kodeMataUang = const Value.absent(),
                Value<int?> kategoriId = const Value.absent(),
                Value<String> siklus = const Value.absent(),
                Value<DateTime> tanggalMulai = const Value.absent(),
                Value<bool> perpanjangOtomatis = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> pauseSejak = const Value.absent(),
                Value<DateTime?> pauseSampai = const Value.absent(),
                Value<String?> metodeBayar = const Value.absent(),
                Value<String?> tautanBayar = const Value.absent(),
                Value<DateTime?> terakhirDipakaiPada = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => LanggananCompanion(
                id: id,
                idLangganan: idLangganan,
                tagihanId: tagihanId,
                nama: nama,
                nominalSen: nominalSen,
                kodeMataUang: kodeMataUang,
                kategoriId: kategoriId,
                siklus: siklus,
                tanggalMulai: tanggalMulai,
                perpanjangOtomatis: perpanjangOtomatis,
                status: status,
                pauseSejak: pauseSejak,
                pauseSampai: pauseSampai,
                metodeBayar: metodeBayar,
                tautanBayar: tautanBayar,
                terakhirDipakaiPada: terakhirDipakaiPada,
                catatan: catatan,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String idLangganan,
                Value<int?> tagihanId = const Value.absent(),
                required String nama,
                Value<int> nominalSen = const Value.absent(),
                Value<String> kodeMataUang = const Value.absent(),
                Value<int?> kategoriId = const Value.absent(),
                Value<String> siklus = const Value.absent(),
                required DateTime tanggalMulai,
                Value<bool> perpanjangOtomatis = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> pauseSejak = const Value.absent(),
                Value<DateTime?> pauseSampai = const Value.absent(),
                Value<String?> metodeBayar = const Value.absent(),
                Value<String?> tautanBayar = const Value.absent(),
                Value<DateTime?> terakhirDipakaiPada = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => LanggananCompanion.insert(
                id: id,
                idLangganan: idLangganan,
                tagihanId: tagihanId,
                nama: nama,
                nominalSen: nominalSen,
                kodeMataUang: kodeMataUang,
                kategoriId: kategoriId,
                siklus: siklus,
                tanggalMulai: tanggalMulai,
                perpanjangOtomatis: perpanjangOtomatis,
                status: status,
                pauseSejak: pauseSejak,
                pauseSampai: pauseSampai,
                metodeBayar: metodeBayar,
                tautanBayar: tautanBayar,
                terakhirDipakaiPada: terakhirDipakaiPada,
                catatan: catatan,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LanggananTable, LanggananData>(table),
                  $$LanggananTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tagihanId = false, kategoriId = false}) {
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
                        referencedTable: $$LanggananTableReferences
                            ._tagihanIdTable(db),
                        referencedColumn: $$LanggananTableReferences
                            ._tagihanIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (kategoriId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.kategoriId,
                        referencedTable: $$LanggananTableReferences
                            ._kategoriIdTable(db),
                        referencedColumn: $$LanggananTableReferences
                            ._kategoriIdTable(db)
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

typedef $$LanggananTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LanggananTable,
      LanggananData,
      $$LanggananTableFilterComposer,
      $$LanggananTableOrderingComposer,
      $$LanggananTableAnnotationComposer,
      $$LanggananTableCreateCompanionBuilder,
      $$LanggananTableUpdateCompanionBuilder,
      (LanggananData, $$LanggananTableReferences),
      LanggananData,
      PrefetchHooks Function({bool tagihanId, bool kategoriId})
    >;
typedef $$AsetTableCreateCompanionBuilder = AsetCompanion Function({
  Value<int> id,
  required String idAset,
  required String nama,
  Value<String> jenis,
  Value<String?> institusi,
  Value<String> kodeMataUang,
  Value<int> nilaiAwalSen,
  Value<bool> likuid,
  Value<bool> arsip,
  Value<String?> catatan,
  Value<DateTime> dibuatPada,
  Value<DateTime> diubahPada,
});
typedef $$AsetTableUpdateCompanionBuilder = AsetCompanion Function({
  Value<int> id,
  Value<String> idAset,
  Value<String> nama,
  Value<String> jenis,
  Value<String?> institusi,
  Value<String> kodeMataUang,
  Value<int> nilaiAwalSen,
  Value<bool> likuid,
  Value<bool> arsip,
  Value<String?> catatan,
  Value<DateTime> dibuatPada,
  Value<DateTime> diubahPada,
});

final class $$AsetTableReferences
    extends BaseReferences<_$AppDatabase, $AsetTable, AsetData> {
  $$AsetTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NilaiAsetBulananTable, List<NilaiAsetBulananData>>
  _nilaiAsetBulananRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.nilaiAsetBulanan,
    aliasName: 'aset__id__nilai_aset_bulanan__aset_id',
  );

  $$NilaiAsetBulananTableProcessedTableManager get nilaiAsetBulananRefs {
    final manager = $$NilaiAsetBulananTableTableManager(
      $_db,
      $_db.nilaiAsetBulanan,
    ).filter((f) => f.asetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _nilaiAsetBulananRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AsetTableFilterComposer extends Composer<_$AppDatabase, $AsetTable> {
  $$AsetTableFilterComposer({
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

  ColumnFilters<String> get idAset => $composableBuilder(
    column: $table.idAset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jenis => $composableBuilder(
    column: $table.jenis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institusi => $composableBuilder(
    column: $table.institusi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nilaiAwalSen => $composableBuilder(
    column: $table.nilaiAwalSen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get likuid => $composableBuilder(
    column: $table.likuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get arsip => $composableBuilder(
    column: $table.arsip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catatan => $composableBuilder(
    column: $table.catatan,
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

  Expression<bool> nilaiAsetBulananRefs(
    Expression<bool> Function($$NilaiAsetBulananTableFilterComposer f) f,
  ) {
    final $$NilaiAsetBulananTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.nilaiAsetBulanan,
      getReferencedColumn: (t) => t.asetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NilaiAsetBulananTableFilterComposer(
            $db: $db,
            $table: $db.nilaiAsetBulanan,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AsetTableOrderingComposer extends Composer<_$AppDatabase, $AsetTable> {
  $$AsetTableOrderingComposer({
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

  ColumnOrderings<String> get idAset => $composableBuilder(
    column: $table.idAset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jenis => $composableBuilder(
    column: $table.jenis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institusi => $composableBuilder(
    column: $table.institusi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nilaiAwalSen => $composableBuilder(
    column: $table.nilaiAwalSen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get likuid => $composableBuilder(
    column: $table.likuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get arsip => $composableBuilder(
    column: $table.arsip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catatan => $composableBuilder(
    column: $table.catatan,
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
}

class $$AsetTableAnnotationComposer
    extends Composer<_$AppDatabase, $AsetTable> {
  $$AsetTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get idAset =>
      $composableBuilder(column: $table.idAset, builder: (column) => column);

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<String> get jenis =>
      $composableBuilder(column: $table.jenis, builder: (column) => column);

  GeneratedColumn<String> get institusi =>
      $composableBuilder(column: $table.institusi, builder: (column) => column);

  GeneratedColumn<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nilaiAwalSen => $composableBuilder(
    column: $table.nilaiAwalSen,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get likuid =>
      $composableBuilder(column: $table.likuid, builder: (column) => column);

  GeneratedColumn<bool> get arsip =>
      $composableBuilder(column: $table.arsip, builder: (column) => column);

  GeneratedColumn<String> get catatan =>
      $composableBuilder(column: $table.catatan, builder: (column) => column);

  GeneratedColumn<DateTime> get dibuatPada => $composableBuilder(
    column: $table.dibuatPada,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get diubahPada => $composableBuilder(
    column: $table.diubahPada,
    builder: (column) => column,
  );

  Expression<T> nilaiAsetBulananRefs<T extends Object>(
    Expression<T> Function($$NilaiAsetBulananTableAnnotationComposer a) f,
  ) {
    final $$NilaiAsetBulananTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.nilaiAsetBulanan,
      getReferencedColumn: (t) => t.asetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NilaiAsetBulananTableAnnotationComposer(
            $db: $db,
            $table: $db.nilaiAsetBulanan,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AsetTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AsetTable,
          AsetData,
          $$AsetTableFilterComposer,
          $$AsetTableOrderingComposer,
          $$AsetTableAnnotationComposer,
          $$AsetTableCreateCompanionBuilder,
          $$AsetTableUpdateCompanionBuilder,
          (AsetData, $$AsetTableReferences),
          AsetData,
          PrefetchHooks Function({bool nilaiAsetBulananRefs})
        > {
  $$AsetTableTableManager(_$AppDatabase db, $AsetTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AsetTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AsetTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AsetTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> idAset = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<String> jenis = const Value.absent(),
                Value<String?> institusi = const Value.absent(),
                Value<String> kodeMataUang = const Value.absent(),
                Value<int> nilaiAwalSen = const Value.absent(),
                Value<bool> likuid = const Value.absent(),
                Value<bool> arsip = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => AsetCompanion(
                id: id,
                idAset: idAset,
                nama: nama,
                jenis: jenis,
                institusi: institusi,
                kodeMataUang: kodeMataUang,
                nilaiAwalSen: nilaiAwalSen,
                likuid: likuid,
                arsip: arsip,
                catatan: catatan,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String idAset,
                required String nama,
                Value<String> jenis = const Value.absent(),
                Value<String?> institusi = const Value.absent(),
                Value<String> kodeMataUang = const Value.absent(),
                Value<int> nilaiAwalSen = const Value.absent(),
                Value<bool> likuid = const Value.absent(),
                Value<bool> arsip = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => AsetCompanion.insert(
                id: id,
                idAset: idAset,
                nama: nama,
                jenis: jenis,
                institusi: institusi,
                kodeMataUang: kodeMataUang,
                nilaiAwalSen: nilaiAwalSen,
                likuid: likuid,
                arsip: arsip,
                catatan: catatan,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AsetTable, AsetData>(table),
                  $$AsetTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({nilaiAsetBulananRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (nilaiAsetBulananRefs) db.nilaiAsetBulanan,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (nilaiAsetBulananRefs)
                    await $_getPrefetchedData<
                      AsetData,
                      $AsetTable,
                      NilaiAsetBulananData
                    >(
                      currentTable: table,
                      referencedTable: $$AsetTableReferences
                          ._nilaiAsetBulananRefsTable(db),
                      managerFromTypedResult: (p0) => $$AsetTableReferences(
                        db,
                        table,
                        p0,
                      ).nilaiAsetBulananRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.asetId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AsetTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AsetTable,
      AsetData,
      $$AsetTableFilterComposer,
      $$AsetTableOrderingComposer,
      $$AsetTableAnnotationComposer,
      $$AsetTableCreateCompanionBuilder,
      $$AsetTableUpdateCompanionBuilder,
      (AsetData, $$AsetTableReferences),
      AsetData,
      PrefetchHooks Function({bool nilaiAsetBulananRefs})
    >;
typedef $$KewajibanTableCreateCompanionBuilder = KewajibanCompanion Function({
  Value<int> id,
  required String idKewajiban,
  required String nama,
  Value<String> jenis,
  Value<int> pokokSen,
  Value<int> saldoAwalSen,
  Value<double?> sukuBungaPersenTahun,
  Value<int?> minimumBayarSen,
  Value<int?> tanggalJatuhTempoHari,
  Value<String> kodeMataUang,
  Value<bool> arsip,
  Value<String?> catatan,
  Value<DateTime> dibuatPada,
  Value<DateTime> diubahPada,
});
typedef $$KewajibanTableUpdateCompanionBuilder = KewajibanCompanion Function({
  Value<int> id,
  Value<String> idKewajiban,
  Value<String> nama,
  Value<String> jenis,
  Value<int> pokokSen,
  Value<int> saldoAwalSen,
  Value<double?> sukuBungaPersenTahun,
  Value<int?> minimumBayarSen,
  Value<int?> tanggalJatuhTempoHari,
  Value<String> kodeMataUang,
  Value<bool> arsip,
  Value<String?> catatan,
  Value<DateTime> dibuatPada,
  Value<DateTime> diubahPada,
});

final class $$KewajibanTableReferences
    extends BaseReferences<_$AppDatabase, $KewajibanTable, KewajibanData> {
  $$KewajibanTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $NilaiKewajibanBulananTable,
    List<NilaiKewajibanBulananData>
  >
  _nilaiKewajibanBulananRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.nilaiKewajibanBulanan,
        aliasName: 'kewajiban__id__nilai_kewajiban_bulanan__kewajiban_id',
      );

  $$NilaiKewajibanBulananTableProcessedTableManager
  get nilaiKewajibanBulananRefs {
    final manager = $$NilaiKewajibanBulananTableTableManager(
      $_db,
      $_db.nilaiKewajibanBulanan,
    ).filter((f) => f.kewajibanId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _nilaiKewajibanBulananRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$KewajibanTableFilterComposer
    extends Composer<_$AppDatabase, $KewajibanTable> {
  $$KewajibanTableFilterComposer({
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

  ColumnFilters<String> get idKewajiban => $composableBuilder(
    column: $table.idKewajiban,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jenis => $composableBuilder(
    column: $table.jenis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pokokSen => $composableBuilder(
    column: $table.pokokSen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get saldoAwalSen => $composableBuilder(
    column: $table.saldoAwalSen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sukuBungaPersenTahun => $composableBuilder(
    column: $table.sukuBungaPersenTahun,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minimumBayarSen => $composableBuilder(
    column: $table.minimumBayarSen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tanggalJatuhTempoHari => $composableBuilder(
    column: $table.tanggalJatuhTempoHari,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get arsip => $composableBuilder(
    column: $table.arsip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catatan => $composableBuilder(
    column: $table.catatan,
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

  Expression<bool> nilaiKewajibanBulananRefs(
    Expression<bool> Function($$NilaiKewajibanBulananTableFilterComposer f) f,
  ) {
    final $$NilaiKewajibanBulananTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.nilaiKewajibanBulanan,
          getReferencedColumn: (t) => t.kewajibanId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NilaiKewajibanBulananTableFilterComposer(
                $db: $db,
                $table: $db.nilaiKewajibanBulanan,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$KewajibanTableOrderingComposer
    extends Composer<_$AppDatabase, $KewajibanTable> {
  $$KewajibanTableOrderingComposer({
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

  ColumnOrderings<String> get idKewajiban => $composableBuilder(
    column: $table.idKewajiban,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jenis => $composableBuilder(
    column: $table.jenis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pokokSen => $composableBuilder(
    column: $table.pokokSen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get saldoAwalSen => $composableBuilder(
    column: $table.saldoAwalSen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sukuBungaPersenTahun => $composableBuilder(
    column: $table.sukuBungaPersenTahun,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minimumBayarSen => $composableBuilder(
    column: $table.minimumBayarSen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tanggalJatuhTempoHari => $composableBuilder(
    column: $table.tanggalJatuhTempoHari,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get arsip => $composableBuilder(
    column: $table.arsip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catatan => $composableBuilder(
    column: $table.catatan,
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
}

class $$KewajibanTableAnnotationComposer
    extends Composer<_$AppDatabase, $KewajibanTable> {
  $$KewajibanTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get idKewajiban => $composableBuilder(
    column: $table.idKewajiban,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<String> get jenis =>
      $composableBuilder(column: $table.jenis, builder: (column) => column);

  GeneratedColumn<int> get pokokSen =>
      $composableBuilder(column: $table.pokokSen, builder: (column) => column);

  GeneratedColumn<int> get saldoAwalSen => $composableBuilder(
    column: $table.saldoAwalSen,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sukuBungaPersenTahun => $composableBuilder(
    column: $table.sukuBungaPersenTahun,
    builder: (column) => column,
  );

  GeneratedColumn<int> get minimumBayarSen => $composableBuilder(
    column: $table.minimumBayarSen,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tanggalJatuhTempoHari => $composableBuilder(
    column: $table.tanggalJatuhTempoHari,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kodeMataUang => $composableBuilder(
    column: $table.kodeMataUang,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get arsip =>
      $composableBuilder(column: $table.arsip, builder: (column) => column);

  GeneratedColumn<String> get catatan =>
      $composableBuilder(column: $table.catatan, builder: (column) => column);

  GeneratedColumn<DateTime> get dibuatPada => $composableBuilder(
    column: $table.dibuatPada,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get diubahPada => $composableBuilder(
    column: $table.diubahPada,
    builder: (column) => column,
  );

  Expression<T> nilaiKewajibanBulananRefs<T extends Object>(
    Expression<T> Function($$NilaiKewajibanBulananTableAnnotationComposer a) f,
  ) {
    final $$NilaiKewajibanBulananTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.nilaiKewajibanBulanan,
          getReferencedColumn: (t) => t.kewajibanId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NilaiKewajibanBulananTableAnnotationComposer(
                $db: $db,
                $table: $db.nilaiKewajibanBulanan,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$KewajibanTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KewajibanTable,
          KewajibanData,
          $$KewajibanTableFilterComposer,
          $$KewajibanTableOrderingComposer,
          $$KewajibanTableAnnotationComposer,
          $$KewajibanTableCreateCompanionBuilder,
          $$KewajibanTableUpdateCompanionBuilder,
          (KewajibanData, $$KewajibanTableReferences),
          KewajibanData,
          PrefetchHooks Function({bool nilaiKewajibanBulananRefs})
        > {
  $$KewajibanTableTableManager(_$AppDatabase db, $KewajibanTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KewajibanTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KewajibanTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KewajibanTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> idKewajiban = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<String> jenis = const Value.absent(),
                Value<int> pokokSen = const Value.absent(),
                Value<int> saldoAwalSen = const Value.absent(),
                Value<double?> sukuBungaPersenTahun = const Value.absent(),
                Value<int?> minimumBayarSen = const Value.absent(),
                Value<int?> tanggalJatuhTempoHari = const Value.absent(),
                Value<String> kodeMataUang = const Value.absent(),
                Value<bool> arsip = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => KewajibanCompanion(
                id: id,
                idKewajiban: idKewajiban,
                nama: nama,
                jenis: jenis,
                pokokSen: pokokSen,
                saldoAwalSen: saldoAwalSen,
                sukuBungaPersenTahun: sukuBungaPersenTahun,
                minimumBayarSen: minimumBayarSen,
                tanggalJatuhTempoHari: tanggalJatuhTempoHari,
                kodeMataUang: kodeMataUang,
                arsip: arsip,
                catatan: catatan,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String idKewajiban,
                required String nama,
                Value<String> jenis = const Value.absent(),
                Value<int> pokokSen = const Value.absent(),
                Value<int> saldoAwalSen = const Value.absent(),
                Value<double?> sukuBungaPersenTahun = const Value.absent(),
                Value<int?> minimumBayarSen = const Value.absent(),
                Value<int?> tanggalJatuhTempoHari = const Value.absent(),
                Value<String> kodeMataUang = const Value.absent(),
                Value<bool> arsip = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => KewajibanCompanion.insert(
                id: id,
                idKewajiban: idKewajiban,
                nama: nama,
                jenis: jenis,
                pokokSen: pokokSen,
                saldoAwalSen: saldoAwalSen,
                sukuBungaPersenTahun: sukuBungaPersenTahun,
                minimumBayarSen: minimumBayarSen,
                tanggalJatuhTempoHari: tanggalJatuhTempoHari,
                kodeMataUang: kodeMataUang,
                arsip: arsip,
                catatan: catatan,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KewajibanTable, KewajibanData>(table),
                  $$KewajibanTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({nilaiKewajibanBulananRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (nilaiKewajibanBulananRefs) db.nilaiKewajibanBulanan,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (nilaiKewajibanBulananRefs)
                    await $_getPrefetchedData<
                      KewajibanData,
                      $KewajibanTable,
                      NilaiKewajibanBulananData
                    >(
                      currentTable: table,
                      referencedTable: $$KewajibanTableReferences
                          ._nilaiKewajibanBulananRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$KewajibanTableReferences(
                            db,
                            table,
                            p0,
                          ).nilaiKewajibanBulananRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.kewajibanId == item.id,
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

typedef $$KewajibanTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KewajibanTable,
      KewajibanData,
      $$KewajibanTableFilterComposer,
      $$KewajibanTableOrderingComposer,
      $$KewajibanTableAnnotationComposer,
      $$KewajibanTableCreateCompanionBuilder,
      $$KewajibanTableUpdateCompanionBuilder,
      (KewajibanData, $$KewajibanTableReferences),
      KewajibanData,
      PrefetchHooks Function({bool nilaiKewajibanBulananRefs})
    >;
typedef $$NilaiAsetBulananTableCreateCompanionBuilder =
    NilaiAsetBulananCompanion Function({
      Value<int> id,
      required int asetId,
      required String bulan,
      required int nilaiSen,
      Value<String> sumber,
      required String idempotensi,
      Value<bool> terkunci,
      Value<DateTime?> dikunciPada,
      Value<String?> catatan,
      Value<DateTime?> dibukaKunciPada,
      Value<String?> alasanBukaKunci,
      Value<DateTime> dibuatPada,
      Value<DateTime> diubahPada,
    });
typedef $$NilaiAsetBulananTableUpdateCompanionBuilder =
    NilaiAsetBulananCompanion Function({
      Value<int> id,
      Value<int> asetId,
      Value<String> bulan,
      Value<int> nilaiSen,
      Value<String> sumber,
      Value<String> idempotensi,
      Value<bool> terkunci,
      Value<DateTime?> dikunciPada,
      Value<String?> catatan,
      Value<DateTime?> dibukaKunciPada,
      Value<String?> alasanBukaKunci,
      Value<DateTime> dibuatPada,
      Value<DateTime> diubahPada,
    });

final class $$NilaiAsetBulananTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $NilaiAsetBulananTable,
          NilaiAsetBulananData
        > {
  $$NilaiAsetBulananTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AsetTable _asetIdTable(_$AppDatabase db) =>
      db.aset.createAlias('nilai_aset_bulanan__aset_id__aset__id');

  $$AsetTableProcessedTableManager get asetId {
    final $_column = $_itemColumn<int>('aset_id')!;

    final manager = $$AsetTableTableManager(
      $_db,
      $_db.aset,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_asetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NilaiAsetBulananTableFilterComposer
    extends Composer<_$AppDatabase, $NilaiAsetBulananTable> {
  $$NilaiAsetBulananTableFilterComposer({
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

  ColumnFilters<int> get nilaiSen => $composableBuilder(
    column: $table.nilaiSen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sumber => $composableBuilder(
    column: $table.sumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotensi => $composableBuilder(
    column: $table.idempotensi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get terkunci => $composableBuilder(
    column: $table.terkunci,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dikunciPada => $composableBuilder(
    column: $table.dikunciPada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catatan => $composableBuilder(
    column: $table.catatan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dibukaKunciPada => $composableBuilder(
    column: $table.dibukaKunciPada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alasanBukaKunci => $composableBuilder(
    column: $table.alasanBukaKunci,
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

  $$AsetTableFilterComposer get asetId {
    final $$AsetTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.asetId,
      referencedTable: $db.aset,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AsetTableFilterComposer(
            $db: $db,
            $table: $db.aset,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NilaiAsetBulananTableOrderingComposer
    extends Composer<_$AppDatabase, $NilaiAsetBulananTable> {
  $$NilaiAsetBulananTableOrderingComposer({
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

  ColumnOrderings<int> get nilaiSen => $composableBuilder(
    column: $table.nilaiSen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sumber => $composableBuilder(
    column: $table.sumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotensi => $composableBuilder(
    column: $table.idempotensi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get terkunci => $composableBuilder(
    column: $table.terkunci,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dikunciPada => $composableBuilder(
    column: $table.dikunciPada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catatan => $composableBuilder(
    column: $table.catatan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dibukaKunciPada => $composableBuilder(
    column: $table.dibukaKunciPada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alasanBukaKunci => $composableBuilder(
    column: $table.alasanBukaKunci,
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

  $$AsetTableOrderingComposer get asetId {
    final $$AsetTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.asetId,
      referencedTable: $db.aset,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AsetTableOrderingComposer(
            $db: $db,
            $table: $db.aset,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NilaiAsetBulananTableAnnotationComposer
    extends Composer<_$AppDatabase, $NilaiAsetBulananTable> {
  $$NilaiAsetBulananTableAnnotationComposer({
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

  GeneratedColumn<int> get nilaiSen =>
      $composableBuilder(column: $table.nilaiSen, builder: (column) => column);

  GeneratedColumn<String> get sumber =>
      $composableBuilder(column: $table.sumber, builder: (column) => column);

  GeneratedColumn<String> get idempotensi => $composableBuilder(
    column: $table.idempotensi,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get terkunci =>
      $composableBuilder(column: $table.terkunci, builder: (column) => column);

  GeneratedColumn<DateTime> get dikunciPada => $composableBuilder(
    column: $table.dikunciPada,
    builder: (column) => column,
  );

  GeneratedColumn<String> get catatan =>
      $composableBuilder(column: $table.catatan, builder: (column) => column);

  GeneratedColumn<DateTime> get dibukaKunciPada => $composableBuilder(
    column: $table.dibukaKunciPada,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alasanBukaKunci => $composableBuilder(
    column: $table.alasanBukaKunci,
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

  $$AsetTableAnnotationComposer get asetId {
    final $$AsetTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.asetId,
      referencedTable: $db.aset,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AsetTableAnnotationComposer(
            $db: $db,
            $table: $db.aset,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NilaiAsetBulananTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NilaiAsetBulananTable,
          NilaiAsetBulananData,
          $$NilaiAsetBulananTableFilterComposer,
          $$NilaiAsetBulananTableOrderingComposer,
          $$NilaiAsetBulananTableAnnotationComposer,
          $$NilaiAsetBulananTableCreateCompanionBuilder,
          $$NilaiAsetBulananTableUpdateCompanionBuilder,
          (NilaiAsetBulananData, $$NilaiAsetBulananTableReferences),
          NilaiAsetBulananData,
          PrefetchHooks Function({bool asetId})
        > {
  $$NilaiAsetBulananTableTableManager(
    _$AppDatabase db,
    $NilaiAsetBulananTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NilaiAsetBulananTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NilaiAsetBulananTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NilaiAsetBulananTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> asetId = const Value.absent(),
                Value<String> bulan = const Value.absent(),
                Value<int> nilaiSen = const Value.absent(),
                Value<String> sumber = const Value.absent(),
                Value<String> idempotensi = const Value.absent(),
                Value<bool> terkunci = const Value.absent(),
                Value<DateTime?> dikunciPada = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime?> dibukaKunciPada = const Value.absent(),
                Value<String?> alasanBukaKunci = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => NilaiAsetBulananCompanion(
                id: id,
                asetId: asetId,
                bulan: bulan,
                nilaiSen: nilaiSen,
                sumber: sumber,
                idempotensi: idempotensi,
                terkunci: terkunci,
                dikunciPada: dikunciPada,
                catatan: catatan,
                dibukaKunciPada: dibukaKunciPada,
                alasanBukaKunci: alasanBukaKunci,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int asetId,
                required String bulan,
                required int nilaiSen,
                Value<String> sumber = const Value.absent(),
                required String idempotensi,
                Value<bool> terkunci = const Value.absent(),
                Value<DateTime?> dikunciPada = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime?> dibukaKunciPada = const Value.absent(),
                Value<String?> alasanBukaKunci = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => NilaiAsetBulananCompanion.insert(
                id: id,
                asetId: asetId,
                bulan: bulan,
                nilaiSen: nilaiSen,
                sumber: sumber,
                idempotensi: idempotensi,
                terkunci: terkunci,
                dikunciPada: dikunciPada,
                catatan: catatan,
                dibukaKunciPada: dibukaKunciPada,
                alasanBukaKunci: alasanBukaKunci,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NilaiAsetBulananTable, NilaiAsetBulananData>(
                    table,
                  ),
                  $$NilaiAsetBulananTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({asetId = false}) {
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
                    if (asetId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.asetId,
                        referencedTable: $$NilaiAsetBulananTableReferences
                            ._asetIdTable(db),
                        referencedColumn: $$NilaiAsetBulananTableReferences
                            ._asetIdTable(db)
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

typedef $$NilaiAsetBulananTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NilaiAsetBulananTable,
      NilaiAsetBulananData,
      $$NilaiAsetBulananTableFilterComposer,
      $$NilaiAsetBulananTableOrderingComposer,
      $$NilaiAsetBulananTableAnnotationComposer,
      $$NilaiAsetBulananTableCreateCompanionBuilder,
      $$NilaiAsetBulananTableUpdateCompanionBuilder,
      (NilaiAsetBulananData, $$NilaiAsetBulananTableReferences),
      NilaiAsetBulananData,
      PrefetchHooks Function({bool asetId})
    >;
typedef $$NilaiKewajibanBulananTableCreateCompanionBuilder =
    NilaiKewajibanBulananCompanion Function({
      Value<int> id,
      required int kewajibanId,
      required String bulan,
      required int nilaiSen,
      Value<String> sumber,
      required String idempotensi,
      Value<bool> terkunci,
      Value<DateTime?> dikunciPada,
      Value<String?> catatan,
      Value<DateTime?> dibukaKunciPada,
      Value<String?> alasanBukaKunci,
      Value<DateTime> dibuatPada,
      Value<DateTime> diubahPada,
    });
typedef $$NilaiKewajibanBulananTableUpdateCompanionBuilder =
    NilaiKewajibanBulananCompanion Function({
      Value<int> id,
      Value<int> kewajibanId,
      Value<String> bulan,
      Value<int> nilaiSen,
      Value<String> sumber,
      Value<String> idempotensi,
      Value<bool> terkunci,
      Value<DateTime?> dikunciPada,
      Value<String?> catatan,
      Value<DateTime?> dibukaKunciPada,
      Value<String?> alasanBukaKunci,
      Value<DateTime> dibuatPada,
      Value<DateTime> diubahPada,
    });

final class $$NilaiKewajibanBulananTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $NilaiKewajibanBulananTable,
          NilaiKewajibanBulananData
        > {
  $$NilaiKewajibanBulananTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $KewajibanTable _kewajibanIdTable(_$AppDatabase db) => db.kewajiban
      .createAlias('nilai_kewajiban_bulanan__kewajiban_id__kewajiban__id');

  $$KewajibanTableProcessedTableManager get kewajibanId {
    final $_column = $_itemColumn<int>('kewajiban_id')!;

    final manager = $$KewajibanTableTableManager(
      $_db,
      $_db.kewajiban,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_kewajibanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NilaiKewajibanBulananTableFilterComposer
    extends Composer<_$AppDatabase, $NilaiKewajibanBulananTable> {
  $$NilaiKewajibanBulananTableFilterComposer({
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

  ColumnFilters<int> get nilaiSen => $composableBuilder(
    column: $table.nilaiSen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sumber => $composableBuilder(
    column: $table.sumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotensi => $composableBuilder(
    column: $table.idempotensi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get terkunci => $composableBuilder(
    column: $table.terkunci,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dikunciPada => $composableBuilder(
    column: $table.dikunciPada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catatan => $composableBuilder(
    column: $table.catatan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dibukaKunciPada => $composableBuilder(
    column: $table.dibukaKunciPada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alasanBukaKunci => $composableBuilder(
    column: $table.alasanBukaKunci,
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

  $$KewajibanTableFilterComposer get kewajibanId {
    final $$KewajibanTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kewajibanId,
      referencedTable: $db.kewajiban,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KewajibanTableFilterComposer(
            $db: $db,
            $table: $db.kewajiban,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NilaiKewajibanBulananTableOrderingComposer
    extends Composer<_$AppDatabase, $NilaiKewajibanBulananTable> {
  $$NilaiKewajibanBulananTableOrderingComposer({
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

  ColumnOrderings<int> get nilaiSen => $composableBuilder(
    column: $table.nilaiSen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sumber => $composableBuilder(
    column: $table.sumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotensi => $composableBuilder(
    column: $table.idempotensi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get terkunci => $composableBuilder(
    column: $table.terkunci,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dikunciPada => $composableBuilder(
    column: $table.dikunciPada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catatan => $composableBuilder(
    column: $table.catatan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dibukaKunciPada => $composableBuilder(
    column: $table.dibukaKunciPada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alasanBukaKunci => $composableBuilder(
    column: $table.alasanBukaKunci,
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

  $$KewajibanTableOrderingComposer get kewajibanId {
    final $$KewajibanTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kewajibanId,
      referencedTable: $db.kewajiban,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KewajibanTableOrderingComposer(
            $db: $db,
            $table: $db.kewajiban,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NilaiKewajibanBulananTableAnnotationComposer
    extends Composer<_$AppDatabase, $NilaiKewajibanBulananTable> {
  $$NilaiKewajibanBulananTableAnnotationComposer({
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

  GeneratedColumn<int> get nilaiSen =>
      $composableBuilder(column: $table.nilaiSen, builder: (column) => column);

  GeneratedColumn<String> get sumber =>
      $composableBuilder(column: $table.sumber, builder: (column) => column);

  GeneratedColumn<String> get idempotensi => $composableBuilder(
    column: $table.idempotensi,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get terkunci =>
      $composableBuilder(column: $table.terkunci, builder: (column) => column);

  GeneratedColumn<DateTime> get dikunciPada => $composableBuilder(
    column: $table.dikunciPada,
    builder: (column) => column,
  );

  GeneratedColumn<String> get catatan =>
      $composableBuilder(column: $table.catatan, builder: (column) => column);

  GeneratedColumn<DateTime> get dibukaKunciPada => $composableBuilder(
    column: $table.dibukaKunciPada,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alasanBukaKunci => $composableBuilder(
    column: $table.alasanBukaKunci,
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

  $$KewajibanTableAnnotationComposer get kewajibanId {
    final $$KewajibanTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kewajibanId,
      referencedTable: $db.kewajiban,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KewajibanTableAnnotationComposer(
            $db: $db,
            $table: $db.kewajiban,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NilaiKewajibanBulananTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NilaiKewajibanBulananTable,
          NilaiKewajibanBulananData,
          $$NilaiKewajibanBulananTableFilterComposer,
          $$NilaiKewajibanBulananTableOrderingComposer,
          $$NilaiKewajibanBulananTableAnnotationComposer,
          $$NilaiKewajibanBulananTableCreateCompanionBuilder,
          $$NilaiKewajibanBulananTableUpdateCompanionBuilder,
          (NilaiKewajibanBulananData, $$NilaiKewajibanBulananTableReferences),
          NilaiKewajibanBulananData,
          PrefetchHooks Function({bool kewajibanId})
        > {
  $$NilaiKewajibanBulananTableTableManager(
    _$AppDatabase db,
    $NilaiKewajibanBulananTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NilaiKewajibanBulananTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NilaiKewajibanBulananTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NilaiKewajibanBulananTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> kewajibanId = const Value.absent(),
                Value<String> bulan = const Value.absent(),
                Value<int> nilaiSen = const Value.absent(),
                Value<String> sumber = const Value.absent(),
                Value<String> idempotensi = const Value.absent(),
                Value<bool> terkunci = const Value.absent(),
                Value<DateTime?> dikunciPada = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime?> dibukaKunciPada = const Value.absent(),
                Value<String?> alasanBukaKunci = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => NilaiKewajibanBulananCompanion(
                id: id,
                kewajibanId: kewajibanId,
                bulan: bulan,
                nilaiSen: nilaiSen,
                sumber: sumber,
                idempotensi: idempotensi,
                terkunci: terkunci,
                dikunciPada: dikunciPada,
                catatan: catatan,
                dibukaKunciPada: dibukaKunciPada,
                alasanBukaKunci: alasanBukaKunci,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int kewajibanId,
                required String bulan,
                required int nilaiSen,
                Value<String> sumber = const Value.absent(),
                required String idempotensi,
                Value<bool> terkunci = const Value.absent(),
                Value<DateTime?> dikunciPada = const Value.absent(),
                Value<String?> catatan = const Value.absent(),
                Value<DateTime?> dibukaKunciPada = const Value.absent(),
                Value<String?> alasanBukaKunci = const Value.absent(),
                Value<DateTime> dibuatPada = const Value.absent(),
                Value<DateTime> diubahPada = const Value.absent(),
              }) => NilaiKewajibanBulananCompanion.insert(
                id: id,
                kewajibanId: kewajibanId,
                bulan: bulan,
                nilaiSen: nilaiSen,
                sumber: sumber,
                idempotensi: idempotensi,
                terkunci: terkunci,
                dikunciPada: dikunciPada,
                catatan: catatan,
                dibukaKunciPada: dibukaKunciPada,
                alasanBukaKunci: alasanBukaKunci,
                dibuatPada: dibuatPada,
                diubahPada: diubahPada,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $NilaiKewajibanBulananTable,
                    NilaiKewajibanBulananData
                  >(table),
                  $$NilaiKewajibanBulananTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({kewajibanId = false}) {
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
                    if (kewajibanId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.kewajibanId,
                        referencedTable: $$NilaiKewajibanBulananTableReferences
                            ._kewajibanIdTable(db),
                        referencedColumn: $$NilaiKewajibanBulananTableReferences
                            ._kewajibanIdTable(db)
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

typedef $$NilaiKewajibanBulananTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NilaiKewajibanBulananTable,
      NilaiKewajibanBulananData,
      $$NilaiKewajibanBulananTableFilterComposer,
      $$NilaiKewajibanBulananTableOrderingComposer,
      $$NilaiKewajibanBulananTableAnnotationComposer,
      $$NilaiKewajibanBulananTableCreateCompanionBuilder,
      $$NilaiKewajibanBulananTableUpdateCompanionBuilder,
      (NilaiKewajibanBulananData, $$NilaiKewajibanBulananTableReferences),
      NilaiKewajibanBulananData,
      PrefetchHooks Function({bool kewajibanId})
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
  $$KategoriTransaksiTableTableManager get kategoriTransaksi =>
      $$KategoriTransaksiTableTableManager(_db, _db.kategoriTransaksi);
  $$TransaksiTableTableManager get transaksi =>
      $$TransaksiTableTableManager(_db, _db.transaksi);
  $$AnggaranBulananTableTableManager get anggaranBulanan =>
      $$AnggaranBulananTableTableManager(_db, _db.anggaranBulanan);
  $$LanggananTableTableManager get langganan =>
      $$LanggananTableTableManager(_db, _db.langganan);
  $$AsetTableTableManager get aset => $$AsetTableTableManager(_db, _db.aset);
  $$KewajibanTableTableManager get kewajiban =>
      $$KewajibanTableTableManager(_db, _db.kewajiban);
  $$NilaiAsetBulananTableTableManager get nilaiAsetBulanan =>
      $$NilaiAsetBulananTableTableManager(_db, _db.nilaiAsetBulanan);
  $$NilaiKewajibanBulananTableTableManager get nilaiKewajibanBulanan =>
      $$NilaiKewajibanBulananTableTableManager(_db, _db.nilaiKewajibanBulanan);
}
