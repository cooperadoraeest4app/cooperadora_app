# Cooperadora App — Documento de Contexto del Proyecto

> Versión 3.0 — Estado actual completo incluyendo implementación.
> Reinsertá este archivo al inicio de cada sesión de trabajo con IA.

---

## 1. Descripción General

Aplicación de gestión financiera y organizacional para Cooperadoras escolares.
- Código abierto en GitHub — cada Cooperadora tiene su propia instancia Firebase
- Multi-usuario con roles diferenciados
- Secciones públicas configurables para transparencia comunitaria
- Sistema democrático de votaciones (pendiente)

---

## 2. Stack Tecnológico

| Componente | Tecnología |
|---|---|
| App móvil (Android) + Web | Flutter 3.44.0 |
| Base de datos | Firebase Firestore |
| Autenticación | Firebase Auth (email/contraseña) |
| Almacenamiento | Firebase Storage (pendiente de uso) |
| Repositorio | GitHub público |
| IDE | VS Code + Claude Code |
| Estado | Provider |

---

## 3. Entorno de Desarrollo

- **SO:** Windows 11 (25H2)
- **Flutter SDK:** `C:\dev\flutter\flutter`
- **Android SDK:** `C:\dev\AndroidSDK`
- **Proyecto:** `C:\dev\proyectos\cooperadora_app`
- **GitHub:** `https://github.com/cooperadoraeest4app/cooperadora_app`
- **Branch:** `main` — sin OneDrive, versionado solo con Git

---

## 4. Arquitectura

### Estructura de carpetas (feature-first)
```
lib/
├── core/theme/app_theme.dart
├── features/
│   ├── auth/
│   ├── admin/
│   ├── home/
│   ├── ingresos/
│   ├── gastos/
│   ├── proyectos/
│   ├── cuenta_bancaria/
│   └── socios/ (pendiente)
└── shared/
    ├── data/categorias_data.dart
    └── services/
```

### Colecciones Firestore
- `ingresos` — movimientos de ingreso
- `gastos` — movimientos de gasto
- `usuarios` — usuarios con rol y authUid
- `personas` — datos personales
- `configuracion` — documento único id: "config"
- `invitaciones` — invitaciones de registro
- `categorias` — categorías de ingresos y gastos
- `metodos_pago` — métodos de pago
- `tipos_proyecto` — tipos de proyecto
- `proyectos` — proyectos de la Cooperadora
- `cuenta_bancaria` — documento único id: "cuenta_principal"
- `movimientos_bancarios` — historial de actualizaciones de saldo

---

## 5. Paleta de Colores

```dart
azulOscuro:     #1A3A5C  // Header, AppBar
azulMedio:      #2E6DA4  // Botones secundarios, íconos
celesteAccento: #8bcbe6  // Avatar, acentos
celesteFondo:   #d6eff9  // Fondo general de la app
celesteBorde:   #b0dff0  // Bordes de cards
verdeTeal:      #2E9E7A  // Botón acción primaria (+ Ingreso)
verdeIngreso:   #27AE60  // Ingresos, estados positivos
rojoGasto:      #E74C3C  // Gastos, estados negativos
amarilloAlerta: #F39C12  // Alertas, proyectos planificados
textoPrincipal: #1A1A2E
textoSecundario:#6B7A99
```

---

## 6. Permisos por Rol

| Acción | Público | Solo lectura | Editor | Admin |
|---|---|---|---|---|
| Ver secciones públicas | ✓ | ✓ | ✓ | ✓ |
| Ver secciones privadas | — | ✓ | ✓ | ✓ |
| Cargar ingresos/gastos | — | — | ✓ | ✓ |
| Gestionar proyectos | — | — | ✓ | ✓ |
| Gestionar socios/cuotas | — | — | ✓ | ✓ |
| Gestionar categorías | — | — | — | ✓ |
| Gestionar usuarios | — | — | — | ✓ |
| Configuración general | — | — | — | ✓ |
| Actualizar saldo bancario | — | — | — | ✓ |
| Ver LogAcceso | — | — | — | ✓ |

---

## 7. Entidades Definidas

### Persona
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `apellido` | string | |
| `dni` | string | |
| `telefono` | string | |
| `email` | string | Opcional |
| `fechaNacimiento` | timestamp | Opcional |
| `direccion` | string | Opcional. Abre Google Maps |
| `fotoUrl` | string | Opcional |
| `cargoId` | string | Opcional |
| `habilidades` | array\<string\> | Opcional |
| `activo` | boolean | |
| `fechaCreacion` | timestamp | |

### Cargo
Cargos por defecto: Presidente, Secretaria, Tesorera, Vocal 1, Vocal 2, Vocal 3, Vocal 1 Suplente, Vocal 2 Suplente, Revisora de Cuenta, Profesora Revisora de Cuenta, Revisora de Cuenta Suplente.

### Usuario
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | Igual al authUid de Firebase |
| `personaId` | string | |
| `authUid` | string | UID de Firebase Auth — IMPORTANTE |
| `rol` | string | `admin` / `editor` / `solo_lectura` / `consultante` |
| `socioId` | string | Opcional |
| `activo` | boolean | |
| `fechaCreacion` | timestamp | |

> El campo `authUid` vincula Firebase Auth con Firestore. Sin este campo el control de roles no funciona.

### Log de Acceso
Sin IP por Ley 25.326. Campos: id, usuarioId, fecha, dispositivo, accion.

### Método de Pago
Por defecto: Efectivo, Transferencia bancaria, Débito, Crédito, Cheque.

### Categoría
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `tipo` | string | `ingreso` / `gasto` |
| `descripcion` | string | Opcional |
| `icono` | string | Material Icons |
| `color` | string | Hex |
| `activa` | boolean | |

Ingresos por defecto: Cuota Social, Donación, Subsidio, Evento, Venta, Otros ingresos.
Gastos por defecto: Servicios, Materiales escolares, Equipamiento, Mantenimiento, Honorarios, Eventos, Otros gastos.

### Frecuencia de Recurrencia
Por defecto: Semanal (7), Quincenal (15), Mensual (30), Bimestral (60), Trimestral (90), Anual (365).

### Ingreso
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `monto` | number | |
| `moneda` | string | Por defecto `"ARS"`. Oculto en interfaz |
| `fecha` | timestamp | |
| `descripcion` | string | Opcional |
| `metodoPagoId` | string | |
| `donante` | string | Opcional. Donante externo |
| `donanteEmail` | string | Opcional |
| `donanteTelefono` | string | Opcional |
| `donanteUsuarioId` | string | Opcional. Donante miembro |
| `categoriaId` | string | Solo tipo ingreso |
| `proyectoId` | string | Opcional |
| `itemProyectoId` | string | Opcional |
| `recurrente` | boolean | |
| `frecuenciaId` | string | Opcional |
| `proximaFecha` | timestamp | Opcional |
| `usuarioId` | string | |
| `comprobante` | string | Opcional |
| `fechaCreacion` | timestamp | |

### Gasto
Igual que Ingreso sin campos de donante.

### Tipo de Socio
Basado en Decreto 4767/72 Art. 40°: Activo (voto), Honorario (voz via delegado), Adherente (voz), Consultante (voz consultiva — categoría propia para alumnos/docentes/no docentes).

### Subtipo de Socio
- Activo, Adherente, Consultante: Padre, Madre, Familiar, Docente, Auxiliar, No docente, Directivo, Alumno, Ex-alumno, Otro
- Honorario: Empresa, Persona física, Organización, Otro

### Socio
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `tipoSocioId` | string | |
| `subtipoSocioId` | string | |
| `apellidoFamilia` | string | Para Activos, Adherentes y Consultantes |
| `razonSocial` | string | Solo Honorarios empresas/organizaciones |
| `cuit` | string | Solo Honorarios |
| `personaContactoId` | string | Para Honorarios: el delegado |
| `activo` | boolean | |
| `fechaIngreso` | timestamp | |
| `observaciones` | string | Opcional |

### Integrante
Vínculo entre Persona y Socio. Campos: id, personaId, socioId, tipo (padre/madre/tutor/alumno), grado (opcional).

### Tipo de Cuota / Tarifa de Cuota / Cuota
Ver definición completa en versión anterior del CONTEXT.

### Tipo de Proyecto
Por defecto: Evento, Infraestructura, Viaje de Estudios, Equipamiento, Otros. Con íconos Material Icons.

### Proyecto
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `descripcion` | string | Opcional |
| `tipoProyectoId` | string | |
| `presupuestoActual` | number | Se recalcula al modificar ítems |
| `fechaInicio` | timestamp | |
| `fechaFinEstimada` | timestamp | Opcional |
| `fechaFinReal` | timestamp | Opcional |
| `estado` | string | `planificado` / `en_curso` / `finalizado` |
| `responsables` | array\<string\> | Lista de usuarioId |
| `publico` | boolean | Por defecto true |
| `votacionId` | string | Opcional |
| `fechaCreacion` | timestamp | |

### Revisión de Presupuesto / Proveedor / Item de Proyecto / Presupuesto de Proveedor
Ver definición completa en versión anterior del CONTEXT.

### Votación y Voto
Pendiente de decisiones institucionales. Confirmado: solo socios Activos votan, Consultantes tienen voz consultiva.

### CuentaBancaria
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | Fijo: `"cuenta_principal"` |
| `banco` | string | |
| `tipoCuenta` | string | Caja de ahorro / Cuenta corriente |
| `cbu` | string | Se muestra solo últimos 4 dígitos públicamente |
| `alias` | string | Copiable al portapapeles |
| `saldoActual` | number | Formato: puntos miles, coma decimales |
| `moneda` | string | Por defecto ARS |
| `activa` | boolean | |
| `fechaActualizacion` | timestamp | |

### MovimientoBancario
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `tipo` | string | `actualizacion_saldo` / `resumen_mensual` |
| `saldoAnterior` | number | |
| `saldoNuevo` | number | |
| `periodo` | string | MM/YYYY — solo resumen_mensual |
| `archivo` | string | URL Firebase Storage — pendiente |
| `observaciones` | string | Opcional, expandibles en UI |
| `usuarioId` | string | |
| `fechaCreacion` | timestamp | |

> Flujo unificado: al actualizar saldo se puede adjuntar el resumen PDF en el mismo formulario.

### Invitacion
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `codigo` | string | 8 caracteres alfanuméricos, generado con Random.secure() |
| `tipo` | string | `individual` / `generica` |
| `rolAsignado` | string | Fijo, el usuario NO puede cambiarlo |
| `nombreDestino` | string | Opcional. Precargado por Admin |
| `apellidoDestino` | string | Opcional |
| `telefonoDestino` | string | Opcional |
| `emailDestino` | string | Solo individual |
| `usada` | boolean | Para individuales |
| `usos` | number | Para genéricas |
| `limiteUsos` | number | Opcional |
| `fechaVencimiento` | timestamp | Opcional |
| `creadaPor` | string | usuarioId del Admin |
| `fechaCreacion` | timestamp | |

### DonacionEspecie (idea futura)
Para registrar donaciones no monetarias (bienes, equipamiento). Conecta con inventario a futuro.

### Configuracion
Documento único id: "config". Incluye: nombreCooperadora, nombreEscuela, emailContacto, telefonoContacto, añoLectivoActivo, quorumMinimoDefault, porcentajeAprobacionDefault, seccionesPublicas (map), monedaDefault, logoUrl.

---

## 8. Estado de Implementación

### Completado ✅
- Entorno de desarrollo configurado
- Firebase: Firestore, Auth, Storage (configurado, pendiente de uso en código)
- Arquitectura feature-first con Provider
- Tema visual completo (paleta celeste/azul/verde)
- **Módulo Ingresos y Gastos:** modelos, repositorios, formulario, listado en tiempo real
- **Autenticación:** login, logout, registro con código de invitación
- **Control de roles:** esAdmin, esEditor, esSoloLectura, esConsultante
- **Panel de administración:** Configuración, Usuarios, Invitaciones, Categorías, Métodos de pago
- **Módulo Cuenta Bancaria:** configuración, saldo con formato argentino, historial con filtros, vista pública
- **Módulo Proyectos:** CRUD completo, tipos con íconos, pantalla pública
- **Pantalla pública (HomeScreen):** saldo, proyectos por estado, últimos movimientos, botones acción rápida

### Detalles técnicos importantes
- `authUid` en documentos `usuarios` vincula Firebase Auth UID con Firestore
- Al registrarse se crean: Auth user + Persona + Usuario en Firestore
- Categorías y métodos de pago se inicializan automáticamente si las colecciones están vacías
- Formulario de movimientos usa categorías hardcodeadas como fallback (migración a Firestore pendiente)
- Saldo bancario: formato con puntos para miles y coma para decimales, decimales en superíndice
- Alias de cuenta bancaria copiable al portapapeles

### Pendiente de implementación
**Alta prioridad:**
- [ ] Migración formulario de movimientos a Firestore (categorías y métodos)
- [ ] Módulo Socios y Cuotas
- [ ] Detalle de proyecto (pantalla individual)
- [ ] Items de Proyecto con proveedores y presupuestos
- [ ] Firebase Storage para comprobantes y resúmenes bancarios

**Media prioridad:**
- [ ] Gráficos y reportes comparativos
- [ ] Notificaciones de gastos recurrentes
- [ ] Login por biometría (huella dactilar)
- [ ] Envío de emails para invitaciones (SendGrid)
- [ ] Sistema de Votaciones

**Baja prioridad / A futuro:**
- [ ] Módulo de habilidades (directorio de oficios)
- [ ] DonacionEspecie
- [ ] Inventario básico
- [ ] Pasantías vinculadas a Socios Honorarios

---

## 9. Historial Cuenta Bancaria — UI

- **Recientes:** últimas 6 entradas, ordenamiento asc/desc
- **Por año:** lista de meses con ícono PDF si tiene resumen, "Sin resumen" si no
- **Por fecha:** selector desde/hasta, paginado de 12, ordenamiento asc/desc
- Observaciones expandibles con flecha
- Vista pública idéntica pero sin opciones de edición

---

## 10. Decisiones de Arquitectura

- Firestore sin migraciones, campos agregables en cualquier momento
- Persona como entidad base: sin duplicación de datos personales
- Voto secreto: socioId no en Voto, participación en array de Votación
- Una instancia Firebase por Cooperadora para mantener gratuidad
- Sin IP en logs por Ley 25.326
- Evento absorbido por Proyecto via TipoProyecto
- Gastos/Ingresos recurrentes via FrecuenciaRecurrencia
- Tipos de socio basados en Decreto 4767/72 Art. 40°
- CuentaBancaria con id fijo "cuenta_principal", escalable a futuro
- Flujo unificado: actualización de saldo + resumen mensual en un solo paso

---

*v3.0 — Módulos Ingresos/Gastos, Cuenta Bancaria y Proyectos implementados y funcionando.*
