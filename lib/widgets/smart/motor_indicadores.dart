import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../dumb/painel_resumo_gerencial.dart';

class MotorIndicadores extends StatelessWidget {
  final String empresaId;
  final String termoBusca;
  final String filtroAtivo;
  final String filtroStatus;
  final List<String> filtroRepresentantes;

  const MotorIndicadores({
    super.key,
    required this.empresaId,
    required this.termoBusca,
    required this.filtroAtivo,
    required this.filtroStatus,
    required this.filtroRepresentantes,
  });

  @override
  Widget build(BuildContext context) {
    // Busca todo o universo da empresa de forma simples e rápida
    Query query = FirebaseFirestore.instance
        .collection('clientes')
        .where('empresa_id', isEqualTo: empresaId);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const PainelResumoGerencial(
            totalClientes: 0,
            clientesNaFila: 0,
            clientesEmAnalise: 0,
          );
        }

        // =====================================================================
        // ESPELHAMENTO DE FILTROS (Igualzinho ao MotorListaClientes)
        // Isso garante que o painel mostre exatamente os números da lista abaixo
        // =====================================================================
        var docsFiltrados = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;

          String razao = (data['razao_social'] ?? '').toString().toLowerCase();
          String fantasia = (data['nome_fantasia'] ?? '')
              .toString()
              .toLowerCase();
          String cnpj = (data['cnpj'] ?? '').toString();
          String ie = (data['ie'] ?? '').toString().toLowerCase();

          String statusCreditoDB = data['status_credito'] ?? 'Em Análise';
          String statusCreditoUI =
              (statusCreditoDB == 'Pendente Enriquecimento')
              ? 'Pendente Cadastro'
              : statusCreditoDB;

          bool isRascunho = data['is_rascunho'] ?? false;
          bool isAtivo = data['ativo'] ?? true;

          String repAtual = (data['representante_id'] ?? 'BOLSÃO').toString();
          if (repAtual == 'Lista Clientes Importada' ||
              repAtual.trim().isEmpty) {
            repAtual = 'BOLSÃO';
          }

          // Aplica o filtro múltiplo de Vendedores
          if (filtroRepresentantes.isNotEmpty &&
              !filtroRepresentantes.contains(repAtual)) {
            return false;
          }

          // Aplica o filtro de Operação (Ativo/Inativo)
          if (filtroAtivo == 'Ativos' && !isAtivo) return false;
          if (filtroAtivo == 'Inativos' && isAtivo) return false;

          // Aplica o filtro de Crédito
          if (filtroStatus == 'Rascunho' && !isRascunho) return false;
          if (filtroStatus != 'Todos' && filtroStatus != 'Rascunho') {
            if (isRascunho || statusCreditoUI != filtroStatus) return false;
          }

          // Aplica a Busca por Texto
          if (termoBusca.isNotEmpty) {
            String busca = termoBusca.toLowerCase();
            if (!razao.contains(busca) &&
                !fantasia.contains(busca) &&
                !cnpj.contains(busca) &&
                !ie.contains(busca)) {
              return false;
            }
          }

          return true;
        }).toList();

        // =====================================================================
        // CÁLCULO DOS INDICADORES COM BASE NA LISTA JÁ FILTRADA
        // =====================================================================

        // 1. Total Base: Quantidade de clientes que sobrou após os filtros
        int total = docsFiltrados.length;

        // 2. Fila de Distrib: Quantos desses filtrados estão no Bolsão
        int naFila = docsFiltrados.where((d) {
          var data = d.data() as Map<String, dynamic>;
          String r = (data['representante_id'] ?? 'BOLSÃO').toString();
          return r == 'BOLSÃO' || r == 'Lista Clientes Importada';
        }).length;

        // 3. Em Análise: Quantos desses filtrados estão pendentes
        int emAnalise = docsFiltrados.where((d) {
          var data = d.data() as Map<String, dynamic>;
          return data['status_credito'] == 'Pendente Enriquecimento';
        }).length;

        return PainelResumoGerencial(
          totalClientes: total,
          clientesNaFila: naFila,
          clientesEmAnalise: emAnalise,
        );
      },
    );
  }
}
