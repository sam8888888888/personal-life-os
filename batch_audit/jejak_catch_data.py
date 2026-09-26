#!/usr/bin/env python3
"""Beri jejak pada `catch (_)` di lapisan data (temuan audit P2-6).

Setiap galat yang ditelan sekarang dicatat lewat `catatGalatTertelan(jenis, e)`
(memori + aliran jejak) supaya kegagalan tidak lagi tidak terlihat. Perilaku
pengguna TIDAK berubah: nilai/misi kembalian tetap sama seperti sebelumnya.
"""
import os
import re
import sys

AKAR = sys.argv[1] if len(sys.argv) > 1 else '.'
os.chdir(AKAR)

# (berkas, penanda_lama, penanda_baru)
GANTI = [
    (
        'lib/data/repository/masjid_repository.dart',
        """    } catch (_) {
      return const HasilMasjid(
        daftar: [],
        dariSimpanan: true,
        pesan: 'Simpanan masjid rusak dan tidak bisa dibaca.',""",
        """    } catch (e) {
      catatGalatTertelan('masjid.simpananRusak', e);
      return const HasilMasjid(
        daftar: [],
        dariSimpanan: true,
        pesan: 'Simpanan masjid rusak dan tidak bisa dibaca.',""",
    ),
    (
        'lib/data/repository/tinjauan_repository.dart',
        """    } catch (_) {
      // arsip lama/rusak: layar tetap menampilkan teksnya, angka dilewati
    }""",
        """    } catch (e) {
      // arsip lama/rusak: layar tetap menampilkan teksnya, angka dilewati —
      // tetapi kegagalannya DICATAT supaya tidak hilang tanpa jejak.
      catatGalatTertelan('tinjauan.angkaArsipRusak', e);
    }""",
    ),
    (
        'lib/data/repository/template_pribadi.dart',
        """    return hasil;
  } catch (_) {
    return const [];
  }""",
        """    return hasil;
  } catch (e) {
    catatGalatTertelan('templatePribadi.bacaRusak', e);
    return const [];
  }""",
    ),
    (
        'lib/data/repository/lampiran_repository.dart',
        """      } catch (_) {
        // Berkas terkunci sistem → baris tetap dihapus, berkas ditinggal.
      }""",
        """      } catch (e) {
        // Berkas terkunci sistem → baris tetap dihapus, berkas ditinggal,
        // tetapi kegagalannya dicatat (bukan dilewatkan tanpa jejak).
        catatGalatTertelan('lampiran.hapusBerkasGagal', e);
      }""",
    ),
    (
        'lib/data/repository/kurs_repository.dart',
        """  } catch (_) {
    throw KursGagal('Jawaban server kurs tidak bisa dibaca.');
  }""",
        """  } catch (e) {
    catatGalatTertelan('kurs.jawabanServerRusak', e);
    throw KursGagal('Jawaban server kurs tidak bisa dibaca.');
  }""",
    ),
    (
        'lib/data/repository/hidup_repository.dart',
        """    } catch (_) {
      // Bila modul aset belum dipakai, biarkan kosong (layar menulis
      // \"belum ada data\") — bukan angka 0 yang menyesatkan.
    }""",
        """    } catch (e) {
      // Bila modul aset belum dipakai, biarkan kosong (layar menulis
      // \"belum ada data\") — bukan angka 0 yang menyesatkan. Kegagalannya
      // tetap dicatat supaya tidak hilang tanpa jejak.
      catatGalatTertelan('hidup.nilaiBersihGagal', e);
    }""",
    ),
]

IMPOR = "import '../../core/notifikasi/jejak.dart';"

for berkas, lama, baru in GANTI:
    if not os.path.exists(berkas):
        print('LEWAT   ', berkas)
        continue
    s = open(berkas, encoding='utf-8').read()
    if lama not in s:
        print('TIDAK COCOK', berkas)
        continue
    s = s.replace(lama, baru, 1)
    if 'catatGalatTertelan' in s and 'notifikasi/jejak.dart' not in s:
        # Sisipkan impor setelah baris impor terakhir di blok impor berkas itu.
        baris = s.split('\n')
        letak = 0
        for i, b in enumerate(baris):
            if b.startswith('import '):
                letak = i
        baris.insert(letak + 1, IMPOR)
        s = '\n'.join(baris)
    open(berkas, 'w', encoding='utf-8').write(s)
    print('DITAMBAL', berkas)

# Sisa catch (_) di lib/data (kalau ada) dilaporkan supaya tidak terlewat.
for akar, _, berkas2 in os.walk('lib/data'):
    for nama in berkas2:
        if nama.endswith('.dart'):
            p = os.path.join(akar, nama)
            isi = open(p, encoding='utf-8').read()
            jumlah = len(re.findall(r'catch \(_\)', isi))
            if jumlah:
                print('SISA    ', p, jumlah)
print('SELESAI')
