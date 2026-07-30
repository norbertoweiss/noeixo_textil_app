import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MotorGeografico {
  /// Recebe a lista de Macro-Regiões (ex: ['Vale Dos príncipes', 'Alto Serra'])
  /// e devolve a lista exata das cidades limpas e em maiúsculo.
  static Future<List<String>> obterCidadesDaRota(
    List<dynamic> regioesDoVendedor,
  ) async {
    List<String> cidadesDaRota = [];

    if (regioesDoVendedor.isEmpty) return cidadesDaRota;

    try {
      final snapRegioes = await FirebaseFirestore.instance
          .collection('regioes_venda')
          .where('nome', whereIn: regioesDoVendedor)
          .where('ativo', isEqualTo: true)
          .get();

      for (var regiaoDoc in snapRegioes.docs) {
        List<dynamic> localidades = regiaoDoc.data()['localidades'] ?? [];

        for (var loc in localidades) {
          String nomeCompleto = loc['nome'] ?? '';

          if (nomeCompleto.contains(' - ')) {
            String apenasCidade = nomeCompleto
                .split(' - ')[0]
                .toUpperCase()
                .trim();
            if (!cidadesDaRota.contains(apenasCidade)) {
              cidadesDaRota.add(apenasCidade);
            }
          } else {
            cidadesDaRota.add(nomeCompleto.toUpperCase().trim());
          }
        }
      }
    } catch (e) {
      debugPrint('Erro no Motor Geográfico: $e');
    }

    return cidadesDaRota;
  }
}
