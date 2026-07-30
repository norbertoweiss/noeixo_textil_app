import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PedidoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================================================================
  // 1. SALVAR PEDIDO (GATILHO NA TELA DE PREVIEW PDF / WHATSAPP)
  // =========================================================================
  Future<String> salvarPedidoOficial({
    required Map<String, dynamic> dadosPedido,
    required String tokenAprovacao,
  }) async {
    try {
      DocumentReference refPedido = _db.collection('pedidos_venda').doc();

      dadosPedido.remove('dataEntregaStr');
      dadosPedido.remove('statusPrevisto');

      dadosPedido['dataPedido'] = FieldValue.serverTimestamp();
      dadosPedido['tokenAprovacao'] = tokenAprovacao;

      String statusVendedor =
          dadosPedido['status'] ?? 'AGUARDANDO APROVAÇÃO DO CLIENTE';

      dadosPedido['status_comercial'] =
          statusVendedor == 'SOB ANÁLISE (DIRETORIA)'
          ? 'Em Análise'
          : 'Pendente Cliente';

      // =========================================================
      // INJEÇÃO DA MÁQUINA DE STATUS ATUALIZADA (COM PCP)
      // =========================================================
      dadosPedido['status_pcp'] = 'Aguardando Comercial';
      dadosPedido['status_financeiro'] = 'Aguardando PCP';
      dadosPedido['status_producao_logistica'] = 'Aguardando';

      String identificacaoVendedor =
          dadosPedido['representanteNome'] ?? 'Vendedor(a)';
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        identificacaoVendedor = user.email!;
      }

      dadosPedido['historico_acoes'] = [
        {
          'data': DateTime.now().toIso8601String(),
          'usuario': identificacaoVendedor,
          'acao': statusVendedor == 'SOB ANÁLISE (DIRETORIA)'
              ? 'Pedido retido (Desconto alto). Aguardando análise da diretoria.'
              : 'Pedido criado no App. Link enviado via WhatsApp.',
        },
      ];

      await refPedido.set(dadosPedido);

      return refPedido.id;
    } catch (e) {
      debugPrint('Erro crítico no PedidoService: $e');
      throw Exception('Falha ao registrar o pedido no banco de dados.');
    }
  }

  // =========================================================================
  // 2. APROVAÇÃO COMERCIAL (Passa o bastão para o PCP)
  // =========================================================================
  Future<void> aprovarComercial({
    required String pedidoId,
    required String nomeUsuarioGestor,
  }) async {
    await _db.collection('pedidos_venda').doc(pedidoId).update({
      'status_comercial': 'Aprovado',
      'status_pcp': 'Em Análise', // A bola agora está com o PCP
      'auditoria_comercial_por': nomeUsuarioGestor,
      'auditoria_comercial_data': FieldValue.serverTimestamp(),
      'checklist_comercial_ok': true,
    });

    await registrarAcaoHistorico(
      pedidoId: pedidoId,
      nomeUsuario: nomeUsuarioGestor,
      acao: 'Checklist Comercial Aprovado. Pedido enviado ao PCP.',
    );
  }

  // =========================================================================
  // 3. APROVAÇÃO PCP (Passa o bastão para o Financeiro)
  // =========================================================================
  Future<void> aprovarPCP({
    required String pedidoId,
    required String nomeUsuarioGestor,
  }) async {
    await _db.collection('pedidos_venda').doc(pedidoId).update({
      'status_pcp': 'Aprovado',
      'status_financeiro': 'Em Análise', // A bola agora está com o Financeiro
      'auditoria_pcp_por': nomeUsuarioGestor,
      'auditoria_pcp_data': FieldValue.serverTimestamp(),
      'checklist_pcp_ok': true,
    });

    await registrarAcaoHistorico(
      pedidoId: pedidoId,
      nomeUsuario: nomeUsuarioGestor,
      acao: 'Checklist PCP Aprovado. Pedido enviado ao Financeiro.',
    );
  }

  // =========================================================================
  // 4. REJEIÇÃO GERAL (Devolve para o Vendedor renegociar)
  // =========================================================================
  Future<void> reprovarPedido({
    required String pedidoId,
    required String etapaReprovacao, // Ex: 'Comercial', 'PCP' ou 'Financeiro'
    required String motivo,
    required String nomeUsuarioGestor,
  }) async {
    await _db.collection('pedidos_venda').doc(pedidoId).update({
      'status_comercial': 'Devolvido',
      'status_pcp': 'Aguardando Comercial',
      'status_financeiro': 'Aguardando PCP',
      'motivo_devolucao': '$etapaReprovacao: $motivo',
      'auditoria_reprovacao_por': nomeUsuarioGestor,
      'auditoria_reprovacao_data': FieldValue.serverTimestamp(),
    });

    await registrarAcaoHistorico(
      pedidoId: pedidoId,
      nomeUsuario: nomeUsuarioGestor,
      acao: 'Pedido reprovado na etapa $etapaReprovacao. Motivo: $motivo',
    );
  }

  // =========================================================================
  // 5. ATUALIZAR STATUS (Mantido por retrocompatibilidade com telas antigas)
  // =========================================================================
  Future<void> atualizarStatusComercial({
    required String pedidoId,
    required String novoStatusComercial,
    required String novoStatusFinanceiro,
    required String nomeUsuarioGestor,
  }) async {
    try {
      await _db.collection('pedidos_venda').doc(pedidoId).update({
        'status_comercial': novoStatusComercial,
        'status_financeiro': novoStatusFinanceiro,
        'data_atualizacao': FieldValue.serverTimestamp(),
      });

      await registrarAcaoHistorico(
        pedidoId: pedidoId,
        nomeUsuario: nomeUsuarioGestor,
        acao: 'Status Comercial alterado para: $novoStatusComercial',
      );
    } catch (e) {
      throw Exception('Erro ao atualizar status do pedido.');
    }
  }

  // =========================================================================
  // 6. REGISTRAR HISTÓRICO DE AÇÕES (LOG DE AUDITORIA CONTÍNUA)
  // =========================================================================
  Future<void> registrarAcaoHistorico({
    required String pedidoId,
    required String nomeUsuario,
    required String acao,
  }) async {
    await _db.collection('pedidos_venda').doc(pedidoId).update({
      'historico_acoes': FieldValue.arrayUnion([
        {
          'data': DateTime.now().toIso8601String(),
          'usuario': nomeUsuario,
          'acao': acao,
        },
      ]),
    });
  }
}
