import 'package:flutter/material.dart';

class PainelResumoGerencial extends StatelessWidget {
  final int totalClientes;
  final int clientesNaFila; // Antigo "Bolsão"
  final int clientesEmAnalise;

  const PainelResumoGerencial({
    super.key,
    required this.totalClientes,
    required this.clientesNaFila,
    required this.clientesEmAnalise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.indigo.shade50,
      child: Row(
        children: [
          _buildInfoCard('Total Base', totalClientes.toString(), Colors.indigo),
          const SizedBox(width: 8),
          _buildInfoCard(
            'Fila de Distrib.',
            clientesNaFila.toString(),
            Colors.purple,
          ),
          const SizedBox(width: 8),
          _buildInfoCard(
            'Em Análise',
            clientesEmAnalise.toString(),
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String titulo, String valor, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border(bottom: BorderSide(color: cor, width: 3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
