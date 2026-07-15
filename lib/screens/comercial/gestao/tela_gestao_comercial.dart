import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../widgets/smart/motor_indicadores.dart';
import '../../../widgets/smart/barra_filtros_comercial.dart';
import '../../../widgets/smart/motor_lista_clientes.dart';
import '../../../widgets/smart/maquina_importacao_csv.dart';
import '../../../widgets/forms/form_ficha_cliente.dart';

class TelaGestaoComercial extends StatefulWidget {
  final String empresaId;

  const TelaGestaoComercial({super.key, required this.empresaId});

  @override
  State<TelaGestaoComercial> createState() => _TelaGestaoComercialState();
}

class _TelaGestaoComercialState extends State<TelaGestaoComercial> {
  String _termoBusca = '';
  String _filtroAtivo = 'Ativos';
  String _filtroStatus = 'Todos';
  String _filtroRepresentante = 'Lista Clientes Importada';

  void _abrirMaquinaImportacao() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
          child: MaquinaImportacaoCSV(empresaId: widget.empresaId),
        ),
      ),
    );
  }

  Future<void> _limparBaseImportada() async {
    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Atenção, Gestor!'),
            content: const Text(
              'Esta ação vai apagar TODOS os clientes que estão na "Fila de Distribuição" gerados pela importação de teste.\n\nOs clientes cadastrados manualmente pelos vendedores não serão afetados. Deseja continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Sim, Apagar Testes',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Iniciando limpeza no banco de dados...')),
    );

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clientes')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('representante_id', isEqualTo: 'Lista Clientes Importada')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${snapshot.docs.length} clientes de teste foram apagados com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao limpar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Carteiras'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'APAGAR DADOS DE TESTE',
            onPressed: _limparBaseImportada,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Novo Cliente',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FormFichaCliente(empresaId: widget.empresaId),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Importar Planilha de Clientes',
            onPressed: _abrirMaquinaImportacao,
          ),
        ],
      ),
      body: Column(
        children: [
          MotorIndicadores(
            empresaId: widget.empresaId,
            termoBusca: _termoBusca,
            filtroAtivo: _filtroAtivo,
            filtroStatus: _filtroStatus,
            filtroRepresentante: _filtroRepresentante,
          ),

          BarraFiltrosComercial(
            termoBusca: _termoBusca,
            filtroAtivo: _filtroAtivo,
            filtroStatus: _filtroStatus,
            filtroRepresentante: _filtroRepresentante,
            onBuscaChanged: (val) => setState(() => _termoBusca = val),
            onAtivoChanged: (val) => setState(() => _filtroAtivo = val!),
            onStatusChanged: (val) => setState(() => _filtroStatus = val!),
            onRepresentanteChanged: (val) =>
                setState(() => _filtroRepresentante = val!),
          ),

          Expanded(
            child: MotorListaClientes(
              empresaId: widget.empresaId,
              termoBusca: _termoBusca,
              filtroAtivo: _filtroAtivo,
              filtroStatus: _filtroStatus,
              filtroRepresentante: _filtroRepresentante,
            ),
          ),
        ],
      ),
    );
  }
}
