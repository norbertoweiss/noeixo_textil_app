import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MotorCartografico {
  static String _padronizarTexto(String texto) {
    if (texto.isEmpty) return '';
    String t = texto.toUpperCase().trim();
    t = t.replaceAll(RegExp(r'[ÁÀÂÃÄ]'), 'A');
    t = t.replaceAll(RegExp(r'[ÉÈÊË]'), 'E');
    t = t.replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I');
    t = t.replaceAll(RegExp(r'[ÓÒÔÕÖ]'), 'O');
    t = t.replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U');
    t = t.replaceAll(RegExp(r'[Ç]'), 'C');
    t = t.replaceAll('-', ' ').replaceAll('"', '').replaceAll("'", "");
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t.trim();
  }

  static Future<List<Polygon>> gerarMapaCalor({
    required List<Map<String, dynamic>> clientes,
    required List<Map<String, dynamic>> regioes,
    required List<String> estadosSelecionados,
  }) async {
    List<Polygon> todosPoligonos = [];

    // Processa a lista de cidades antes de carregar os mapas
    Set<String> cidadesComClientes = {};
    for (var cli in clientes) {
      String cidade = (cli['cidade'] ?? cli['cidade_fiscal'] ?? '').toString();
      if (cidade.isNotEmpty) cidadesComClientes.add(_padronizarTexto(cidade));
    }

    Set<String> cidadesDemarcadas = {};
    for (var regiao in regioes) {
      for (var loc in (regiao['localidades'] ?? [])) {
        String nomeCid = (loc['nome'] ?? '').toString().split('-')[0];
        cidadesDemarcadas.add(_padronizarTexto(nomeCid));
      }
    }

    // Carrega cada arquivo solicitado na lista estadosSelecionados
    for (String sigla in estadosSelecionados) {
      try {
        final String geoJsonString = await rootBundle.loadString(
          'assets/mapas/$sigla.json',
        );
        final data = json.decode(geoJsonString);

        if (data['type'] == 'FeatureCollection') {
          for (var feature in data['features']) {
            var geometry = feature['geometry'];
            var props = feature['properties'] ?? {};

            // Identifica o nome da cidade
            String nome =
                (props['NM_MUN'] ?? props['name'] ?? props['nm_mun'] ?? '')
                    .toString();
            String nomeLimpo = _padronizarTexto(nome);

            if (geometry != null) {
              // ==========================================
              // LÓGICA DE CORES (BORDA + MIOLO)
              // ==========================================
              Color cor = Colors.transparent;
              Color borda = Colors
                  .blueGrey
                  .shade400; // Cidades vazias mantêm borda fina e cinza
              double espessura = 1.0;

              if (cidadesComClientes.contains(nomeLimpo) &&
                  cidadesDemarcadas.contains(nomeLimpo)) {
                // AZUL: Tem Cliente e Tem Região
                cor = Colors.blue.withOpacity(
                  0.55,
                ); // Miolo como vidro colorido
                borda = Colors.blue.shade900; // Borda forte
                espessura = 2.5;
              } else if (cidadesComClientes.contains(nomeLimpo)) {
                // LARANJA: Tem Cliente mas NÃO tem Região
                cor = Colors.orange.withOpacity(0.55);
                borda = Colors.deepOrange.shade900;
                espessura = 2.5;
              } else if (cidadesDemarcadas.contains(nomeLimpo)) {
                // CINZA: Tem Região mas NÃO tem Cliente
                cor = Colors.grey.withOpacity(0.55);
                borda = Colors.grey.shade800;
                espessura = 2.5;
              }

              if (geometry['type'] == 'Polygon') {
                todosPoligonos.add(
                  _montarPoligonoVisual(
                    geometry['coordinates'][0],
                    cor,
                    borda,
                    espessura,
                  ),
                );
              } else if (geometry['type'] == 'MultiPolygon') {
                for (var coord in geometry['coordinates']) {
                  todosPoligonos.add(
                    _montarPoligonoVisual(coord[0], cor, borda, espessura),
                  );
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar mapa do estado $sigla: $e');
      }
    }
    return todosPoligonos;
  }

  static Polygon _montarPoligonoVisual(
    List<dynamic> coords,
    Color preenchimento,
    Color borda,
    double espessura,
  ) {
    List<LatLng> pontos = [];
    for (var coord in coords) pontos.add(LatLng(coord[1], coord[0]));

    return Polygon(
      points: pontos,
      color: preenchimento, // Pinta o miolo
      borderColor: borda, // Pinta a linha externa
      borderStrokeWidth: espessura,
      isFilled:
          preenchimento !=
          Colors
              .transparent, // Ordem explícita: Se não for transparente, force o preenchimento!
    );
  }
}
