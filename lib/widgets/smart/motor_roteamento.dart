import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MotorRoteamento {
  /// Executa a varredura completa do banco e distribui os clientes
  /// de acordo com a malha geográfica atualizada.
  static Future<void> sincronizarGeral() async {
    final db = FirebaseFirestore.instance;

    try {
      debugPrint('⚙️ MOTOR DE ROTEAMENTO: Iniciando mapeamento...');

      // 1. Mapear Vendedores e suas Regiões
      // Cria um dicionário: Nome da Região -> ID do Vendedor
      final snapVendedores = await db
          .collection('vendedores')
          .where('ativo', isEqualTo: true)
          .get();
      Map<String, String> mapaRegiaoVendedor = {};

      for (var doc in snapVendedores.docs) {
        var dados = doc.data();
        List regioes = dados['regioes_vinculadas'] ?? [];
        for (var regiao in regioes) {
          mapaRegiaoVendedor[regiao.toString()] = doc.id;
        }
      }

      // 2. Mapear Cidades e suas Regiões
      // Cria um dicionário: "Cidade - UF" -> Nome da Região
      final snapRegioes = await db
          .collection('regioes_venda')
          .where('ativo', isEqualTo: true)
          .get();
      Map<String, String> mapaCidadeRegiao = {};

      for (var doc in snapRegioes.docs) {
        var dados = doc.data();
        String nomeRegiao = dados['nome'];
        List localidades = dados['localidades'] ?? [];

        for (var loc in localidades) {
          // O nome já é salvo no formato "Cidade - UF" ou "Cidade - UF [Bairro: X]"
          mapaCidadeRegiao[loc['nome'].toString()] = nomeRegiao;
        }
      }

      // 3. Puxar todos os Clientes Ativos
      final snapClientes = await db
          .collection('clientes')
          .where('ativo', isEqualTo: true)
          .get();

      // 4. Preparar o Lote de Atualizações (Batch)
      WriteBatch batch = db.batch();
      int alteracoes = 0;

      for (var doc in snapClientes.docs) {
        var cliente = doc.data();
        String repAtual =
            cliente['representante_id'] ?? 'Lista Clientes Importada';

        String cidade = (cliente['cidade_fiscal'] ?? '').toString().trim();
        String uf = (cliente['uf_fiscal'] ?? '').toString().trim();

        if (cidade.isEmpty || uf.isEmpty) continue;

        // Monta a chave de busca para cruzar com o mapa (Ex: "Blumenau - SC")
        String chaveCidade = '$cidade - $uf';

        // Descobre a qual Região essa cidade pertence
        String? regiaoDoCliente = mapaCidadeRegiao[chaveCidade];

        if (regiaoDoCliente != null) {
          // Descobre qual Vendedor atende essa Região
          String? vendedorDono = mapaRegiaoVendedor[regiaoDoCliente];

          if (vendedorDono != null && repAtual != vendedorDono) {
            // O cliente está com o representante errado ou no Bolsão. Atualiza!
            batch.update(doc.reference, {
              'representante_id': vendedorDono,
              'data_roteamento': FieldValue.serverTimestamp(),
            });
            alteracoes++;
          }
        }
      }

      // 5. Executa as alterações em massa no Firebase
      if (alteracoes > 0) {
        await batch.commit();
        debugPrint(
          '✅ MOTOR DE ROTEAMENTO: Sincronização concluída. $alteracoes clientes redirecionados.',
        );
      } else {
        debugPrint(
          '✅ MOTOR DE ROTEAMENTO: Nenhuma alteração necessária. Malha intacta.',
        );
      }
    } catch (e) {
      debugPrint('❌ ERRO NO MOTOR DE ROTEAMENTO: $e');
    }
  }
}
