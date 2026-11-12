// lib/models/github_repo_info.dart
//
// Resumen de solo lectura de un repositorio de GitHub. No se persiste en
// Firestore -- se consulta en vivo cada vez que se abre la ficha del
// proyecto (ver GithubService), igual criterio que ProgresoResultado: es
// el resultado de una consulta, no un dato propio de AppsDoc.
class GithubRepoInfo {
  const GithubRepoInfo({
    required this.propietario,
    required this.nombre,
    required this.ramaPrincipal,
    required this.ultimoCommitMensaje,
    required this.ultimoCommitFecha,
    required this.actualizadoEn,
  });

  final String propietario;
  final String nombre;
  final String ramaPrincipal;
  final String ultimoCommitMensaje;
  final DateTime ultimoCommitFecha;
  final DateTime actualizadoEn;
}
