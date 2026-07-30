import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MotorRoteamento {
  /// Função interna para limpar textos: remove acentos e deixa tudo maiúsculo.
  /// Isso garante que "Camboriú", "CAMBORIU" e "camboriu" sejam lidos como a mesma cidade.
  static String _padronizarTexto(String texto) {
    if (texto.isEmpty) return '';
    String t = texto.toUpperCase().trim();
    t = t.replaceAll(RegExp(r'[ÁÀÂÃÄ]'), 'A');
    t = t.replaceAll(RegExp(r'[ÉÈÊË]'), 'E');
    t = t.replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I');
    t = t.replaceAll(RegExp(r'[ÓÒÔÕÖ]'), 'O');
    t = t.replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U');
    t = t.replaceAll(RegExp(r'[Ç]'), 'C');
    return t;
  }

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

      // 2. Mapear Cidades e suas Regiões (Aplicando a padronização)
      // Cria um dicionário: "CIDADE - UF" -> Nome da Região
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
          // Limpa o nome que veio do IBGE (Ex: "Camboriú - SC" vira "CAMBORIU - SC")
          String cidadeLimpa = _padronizarTexto(loc['nome'].toString());
          mapaCidadeRegiao[cidadeLimpa] = nomeRegiao;
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

        // Trata os clientes que estão no Bolsão ou com texto antigo
        String repAtual = (cliente['representante_id'] ?? 'BOLSÃO').toString();
        if (repAtual == 'Lista Clientes Importada' || repAtual.trim().isEmpty) {
          repAtual = 'BOLSÃO';
        }

        // Usa a leitura elástica para a cidade e UF, garantindo que não pule ninguém
        String cidade = (cliente['cidade_fiscal'] ?? cliente['cidade'] ?? '')
            .toString();
        String uf = (cliente['uf_fiscal'] ?? cliente['estado'] ?? '')
            .toString();

        if (cidade.isEmpty || uf.isEmpty) continue;

        // Monta a chave de busca do cliente (Ex: "CAMBORIU - SC") já padronizada
        String chaveCidadeCliente = _padronizarTexto('$cidade - $uf');

        // Pergunta ao dicionário: "De quem é essa cidade?"
        String? regiaoDoCliente = mapaCidadeRegiao[chaveCidadeCliente];

        if (regiaoDoCliente != null) {
          // Descobre qual Vendedor atende essa Região
          String? vendedorDono = mapaRegiaoVendedor[regiaoDoCliente];

          // Se achou um vendedor e o cliente não está com ele, transfere!
          if (vendedorDono != null && repAtual != vendedorDono) {
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
