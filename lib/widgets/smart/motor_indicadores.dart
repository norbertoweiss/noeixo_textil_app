import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../dumb/painel_resumo_gerencial.dart';

class MotorIndicadores extends StatelessWidget {
  final String empresaId;
  final String termoBusca;
  final String filtroAtivo;
  final String filtroStatus;
  final String filtroRepresentante;

  const MotorIndicadores({
    super.key,
    required this.empresaId,
    required this.termoBusca,
    required this.filtroAtivo,
    required this.filtroStatus,
    required this.filtroRepresentante,
  });

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('clientes')
        .where('empresa_id', isEqualTo: empresaId);

    if (filtroRepresentante != 'Todos') {
      query = query.where('representante_id', isEqualTo: filtroRepresentante);
    }
    if (filtroAtivo == 'Ativos') {
      query = query.where('ativo', isEqualTo: true);
    } else if (filtroAtivo == 'Inativos') {
      query = query.where('ativo', isEqualTo: false);
    }
    if (filtroStatus != 'Todos') {
      query = query.where('status_credito', isEqualTo: filtroStatus);
    }

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

        var docs = snapshot.data!.docs;

        if (termoBusca.isNotEmpty) {
          docs = docs.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            String razao = (d['razao_social'] ?? '').toString().toLowerCase();
            String fantasia = (d['nome_fantasia'] ?? '')
                .toString()
                .toLowerCase();
            String cnpj = (d['cnpj'] ?? '').toString();
            String ie = (d['ie'] ?? '').toString().toLowerCase();
            String busca = termoBusca.toLowerCase();
            return razao.contains(busca) ||
                fantasia.contains(busca) ||
                cnpj.contains(busca) ||
                ie.contains(busca);
          }).toList();
        }

        int total = docs.length;

        int naFila = docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          return data['representante_id'] == 'Lista Clientes Importada';
        }).length;

        int emAnalise = docs.where((d) {
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
