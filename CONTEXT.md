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

---

## 12. Actualizaciones de Roles y Auditoría

### Nuevo rol: Auditor
Agregado entre `solo_lectura` y `editor`. Acceso de solo lectura más visibilidad del log de cambios.

**Tabla de permisos actualizada:**

| Acción | Público | Consultante | Solo lectura | Auditor | Editor | Admin |
|---|---|---|---|---|---|---|
| Ver secciones públicas | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Ver secciones privadas | — | — | ✓ | ✓ | ✓ | ✓ |
| Ver log de cambios | — | — | — | ✓ | — | ✓ |
| Cargar ingresos/gastos | — | — | — | — | ✓ | ✓ |
| Editar ingresos/gastos | — | — | — | — | ✓ | ✓ |
| Gestionar proyectos | — | — | — | — | ✓ | ✓ |
| Gestionar categorías | — | — | — | — | — | ✓ |
| Gestionar usuarios | — | — | — | — | — | ✓ |
| Configuración general | — | — | — | — | — | ✓ |

> Vocales y Revisoras de Cuenta reciben rol `auditor` para acceder al log de cambios.

### Entidad LogCambio
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `entidadTipo` | string | `ingreso` / `gasto` / `cuota` / `proyecto` |
| `entidadId` | string | ID del documento modificado |
| `usuarioId` | string | Quién hizo el cambio |
| `fecha` | timestamp | Cuándo |
| `camposAnteriores` | map | Valores antes del cambio |
| `camposNuevos` | map | Valores después del cambio |
| `accion` | string | `creacion` / `modificacion` / `eliminacion` |

### Vista de detalle de movimientos
- Item del listado expandible con flecha (igual que historial bancario)
- Al expandir muestra: categoría con ícono, método de pago con ícono, descripción, donante, comprobante descargable, quién cargó y cuándo
- Botón editar solo para Editor/Admin
- Comprobante visible también en pantalla pública si el movimiento es público


---

## 13. Actualizaciones Recientes

### Reglas de Seguridad Firestore
Archivo `firestore.rules` implementado y desplegado. Resumen:
- **Lectura pública:** configuracion, categorias, tipos_proyecto, metodos_pago, cuenta_bancaria, movimientos_bancarios, proyectos, items_proyecto, ingresos, gastos, frecuencias_recurrencia
- **Solo autenticados:** usuarios, personas, socios, integrantes, cuotas, tarifas_cuota, tipos_cuota, invitaciones, proveedores, presupuestos_proveedor
- **Solo Auditor/Admin:** log_cambios
- **Solo Admin:** escritura en configuracion, categorias, metodos_pago, cuenta_bancaria, tarifas_cuota, tipos_cuota, frecuencias_recurrencia
- **Editor y Admin:** escritura en ingresos, gastos, proyectos, items_proyecto, socios, integrantes, cuotas, personas, proveedores
- **Verificación de usuario activo:** `estaActivo()` en todas las escrituras de Editor

### Módulos implementados adicionales
- **Firebase Storage:** comprobantes en ingresos, gastos y cuotas. Path: `comprobantes/{tipo}/{año}/{mes}/`
- **Log de cambios:** colección `log_cambios` con campos entidadTipo, entidadId, usuarioId, fecha, camposAnteriores, camposNuevos, accion. Visible para Admin y Auditor.
- **Rol Auditor:** nuevo rol entre solo_lectura y editor. Acceso de solo lectura + log de cambios.
- **Items expandibles en movimientos:** detalle inline con categoría, método de pago, donante, comprobante, quién cargó, botones editar/eliminar según rol.
- **Edición de movimientos:** formulario reutilizable con modo edición.
- **Recurrencia:** campos recurrente, frecuenciaId, proximaFecha en Ingreso y Gasto. Filtro en listado.
- **Detalle proyecto público:** pantalla de solo lectura con ítems y movimientos del proyecto.
- **Comprobantes públicos:** visibles y descargables sin login.

### Estado actual de implementación
**Completado ✅**
- Toda la infraestructura Firebase (Auth, Firestore, Storage, Rules)
- Módulo Ingresos y Gastos completo con edición, log, recurrencia, comprobantes
- Módulo Cuenta Bancaria completo con historial y vista pública
- Módulo Proyectos completo con detalle público e ítems
- Módulo Socios y Cuotas completo
- Panel de administración completo
- Sistema de autenticación con invitaciones
- Control de roles (admin, editor, solo_lectura, auditor, consultante)
- Pantalla pública (HomeScreen) completa
- Log de cambios con auditoría

**Pendiente 🔲**
- Gráficos y reportes comparativos
- Notificaciones push para Android
- Build para Android
- Reglas de seguridad Firebase Storage
- Módulo Votaciones (requiere decisiones institucionales)


---

## 14. Sesión de Auditoría y Refinamiento — Actualizaciones

### Widgets compartidos creados
- **`AccionAuthWidget`** (`lib/shared/widgets/accion_auth_widget.dart`): botón Ingresar / avatar con menú desplegable (Mi perfil, Panel de administración si esAdmin||esAuditor, Cerrar sesión). Usado en TODAS las pantallas con AppBar.
- **`NombreUsuarioWidget`** (`lib/shared/widgets/nombre_usuario_widget.dart`): resuelve un `usuarioId` a nombre completo (vía `personaId`) o email como fallback. Muestra `SizedBox.shrink()` si el usuario no está logueado. Usa guard de loading para evitar mostrar IDs crudos.

### Sistema de auditoría — patrón estándar
Aplicado a: Ingresos, Gastos, Proyectos, Ítems de Proyecto, Cuenta Bancaria.

Cada entidad auditable tiene `usuarioId` (creador), `ultimaModificacionPor` (nullable), `ultimaModificacionFecha` (nullable). Cada operación se registra en `log_cambios` vía `LogCambioService.registrar()`.

UI: "Creado por: {nombre}" y "Última modificación: {nombre} · {fecha}" con `NombreUsuarioWidget`, label en negrita, mismo tamaño que el texto circundante de la sección.

### Pantallas unificadas
Eliminadas pantallas públicas separadas: `ProyectoPublicoDetalleScreen` y `CuentaBancariaPublicaScreen`. Ahora una sola pantalla por módulo verifica el rol y muestra campos editables o de solo lectura según corresponda.

### Patrón ListTile en dropdowns (CRÍTICO)
Cualquier Row con texto sin Expanded dentro de DropdownMenuItem rompe el layout en Flutter web. Usar siempre ListTile dense con leading/title, y selectedItemBuilder con solo texto.

### Bugs resueltos
- Usuarios duplicados en Firestore por migración manual de authUid — un solo documento por usuario con ID = authUid.
- Reglas de Firestore: usar exists() antes de get() en funciones de rol para evitar permission-denied en falsos negativos.
- Subcolección cuenta bancaria: movimientos están en cuenta_bancaria/cuenta_principal/movimientos, no en colección top-level.
- Auto-creación de Persona si el usuario no tiene personaId al editar perfil.
- Registro con invitación: recargarRol() explícito tras crear usuario, navegación con pushAndRemoveUntil a HomeScreen.

### Funcionalidades agregadas
- Filtro de recurrencia con dropdown de Frecuencia en Movimientos y Home.
- Proyecto asociado opcional en Ingreso/Gasto, con link presionable en el detalle.
- Firebase Storage para resúmenes bancarios: comprobantes/resumenes_bancarios/{año}/{mes}/.
- Log de cambios con tipos: ingreso, gasto, proyecto, item_proyecto, cuenta_bancaria.
- Pantalla de perfil de usuario con edición inline y cambio de contraseña.


---

## 15. Entidad Inventario

### BienInventario
Registro legal de bienes muebles de la Cooperadora (comprados o donados). NO incluye materiales consumibles (librería, juguetería, etc.).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `codigo` | string | Código único auto-generado. Formato: INV-{año}-{nro correlativo} |
| `descripcion` | string | Qué es el bien (marca, color, características) |
| `estado` | string | `bueno` / `regular` / `malo` / `dado_de_baja` |
| `ubicacion` | string | Opcional. Ej: "Aula 3", "Depósito" |
| `categoriaInventario` | string | Opcional. Ej: "Mobiliario", "Tecnología", "Musical" |
| `fechaAlta` | timestamp | Fecha de compra o recepción |
| `nroActaAlta` | string | Número de acta de aprobación |
| `cantidadAlta` | number | Cantidad recibida |
| `tipoAlta` | string | `compra` / `donacion` |
| `valorAlta` | number | Monto de compra o valor estimado. Null si no calculable |
| `gastoId` | string | Opcional. Vincula con Gasto si fue compra |
| `ingresoId` | string | Opcional. Vincula con Ingreso si fue donación |
| `usuarioAltaId` | string | Quién registró el alta |
| `fechaBaja` | timestamp | Opcional |
| `nroActaBaja` | string | Opcional |
| `cantidadBaja` | number | Opcional |
| `motivoBaja` | string | `venta` / `deterioro` / `rotura` / `robo` / `donacion` / `permuta` / `otro` |
| `valorBaja` | number | Opcional. Monto de venta o valor de permuta |
| `usuarioBajaId` | string | Quién registró la baja |
| `ultimaModificacionPor` | string | Nullable |
| `ultimaModificacionFecha` | timestamp | Nullable |

**Permisos:** Alta y baja por Editor/Admin. Visibilidad configurable por Admin (visible por defecto).

**Integración con Gastos/Ingresos:** toggle opcional en el formulario al seleccionar categorías que impliquen bienes muebles. Al activar aparece mini-formulario inline con datos del alta. Al guardar se crea el bien en inventario vinculado por `gastoId` o `ingresoId`.

**Colección Firestore:** `inventario`


---

## 16. Actualizaciones Recientes — Segunda Sesión

### Módulo Caja Chica
Documento fijo `"caja_chica"` en colección `cuenta_bancaria`. Movimientos en subcolección `cuenta_bancaria/caja_chica/movimientos`.

**Permisos:** Editor y Admin pueden actualizar el saldo (no solo Admin).

**Integración automática:**
- Ingreso en efectivo → suma automáticamente a Caja Chica
- Gasto en efectivo → resta automáticamente de Caja Chica
- Depósito bancario desde Caja Chica → operación atómica (batch write) que descuenta Caja Chica y suma Cuenta Bancaria simultáneamente

**UI:** Tab "Caja Chica" en `cuenta_bancaria_screen.dart` junto a tab "Cuenta Bancaria". Botón "Depositar al banco" visible para Editor/Admin.

### Módulo Inventario
Colección `inventario`. Código auto-generado formato `INV-{año}-{correlativo}`.

**Integración con Gastos/Ingresos:** toggle opcional en formulario al seleccionar categorías que impliquen bienes muebles. Al activar aparece mini-formulario inline. Al guardar se crea automáticamente el bien vinculado por `gastoId` o `ingresoId`.

**Permisos:** Alta y baja por Editor/Admin. Visible públicamente por defecto (configurable por Admin).

**UI:** `InventarioScreen` con filtros por estado, acceso desde panel admin y desde HomeScreen.

### Módulo Cuota Social integrado con Ingresos
Cuando categoría es "Cuota Social":
- Se ocultan campos no aplicables: proyecto, donante, recurrencia
- Aparecen campos: socio (autocomplete), período MM/YYYY, monto precargado desde tarifa vigente
- Al guardar se registra automáticamente la cuota del socio seleccionado

### Filtros en pantalla Movimientos
Panel desplegable (botón "Filtros" con badge de cantidad activos) visible solo para usuarios logueados. Filtros: tipo (Ingresos/Gastos/Ambos), fecha desde/hasta, categoría, forma de pago, usuario (con checkboxes "Creado por" / "Modificado por").

### Libro de Actas — Pendiente con restricción legal
El manual de Cooperadoras ABC.gob.ar exige que las actas sean escritas de puño y letra en libro físico, sin hojas agregadas ni impresiones. La app puede funcionar como borrador digital y archivo de fotos/PDF del libro físico, pero NO puede reemplazar el libro legal. Implementación postergada.

### Libros obligatorios — Estado
- ✅ Libro de socios — módulo Socios
- ✅ Libro de tesorería — módulo Ingresos y Gastos
- ✅ Libro inventario — módulo Inventario
- ✅ Comprobantes correlativos — Firebase Storage
- 🔲 Libro de actas — requiere libro físico por ley

### TODO pendiente en código
`// TODO: Mecanismo de adelanto y reintegro — gasto adelantado por miembro, se asienta al momento del reintegro desde Caja Chica.`


---

## 17. Rediseño del Modelo Persona-Socio-Usuario (CAMBIO ESTRUCTURAL)

> IMPORTANTE: Este rediseño reemplaza el modelo anterior de Socio como grupo familiar con Integrantes. Según el manual de Cooperadoras ABC.gob.ar, el Socio es una Persona individual con número de socio propio, no un grupo. Se elimina la entidad Integrante.

### Motivación
El manual establece que cada Socio debe tener: número de socio único, nombre y apellido, DNI, domicilio, teléfono y email — datos de una persona, no de un grupo familiar. Si padre y madre quieren ambos tener voz/voto, cada uno se inscribe como Socio individual con su propio número.

### Persona — Modelo actualizado

Campos nuevos respecto al modelo anterior: tipoPersona (fisica/fiscal), fechaNacimiento (nuevo, para todas las personas físicas), razonSocial, cuit, personaContactoId (solo fiscal), subtipo, cursoId (solo alumnos), hijosIds (opcional, informativo).

Regla automática: si tipoPersona es fiscal, el Socio asociado es automáticamente tipo honorario.

### Curso — Nueva entidad catálogo
Campos: id, nombre (ej 3 B), nivel (opcional), orden (opcional - si no se define, dropdown ordena alfabéticamente por nombre), activo. Gestionable desde panel Admin. Colección: cursos.

### Socio — Modelo simplificado
Campos: id, numeroSocio (correlativo único, obligatorio por ley), personaId (reemplaza apellidoFamilia), tipoSocio (activo/honorario/adherente, derivado automático a honorario si persona es fiscal), activo, fechaIngreso, observaciones.

### Entidad eliminada: Integrante
Ya no existe. La relación familiar informativa se maneja con hijosIds en Persona.

### Tipos de Socio segun Art 40 Decreto 4767/72
1. Socio Activo - Persona Fisica mayor de edad vinculada a la comunidad escolar. Paga cuota. Voz y voto.
2. Socio Honorario - Persona Fiscal o Fisica que colabore. Solo voz, mediante delegado (personaContactoId).
3. Socio Adherente - Persona Fisica mayor de 15 anios, cuota inferior. Solo voz, sin voto.

Consultante sigue existiendo como categoria propia de la app (no legal) para Usuarios sin condicion de Socio que quieran expresar opinion.

### Votaciones - Separacion de resultados (a implementar)
Resultado vinculante: solo votos de Socios Activos. Por separado: Opinion de la comunidad con votos de Consultantes, sin peso legal, desglosado, nunca mezclado con el resultado oficial.

### Migracion de datos pendiente
Los Socios existentes (grupo familiar con apellidoFamilia) deben convertirse en Socios individuales vinculados a una Persona. Los Integrantes existentes deben revisarse uno por uno. Reasignar numeroSocio correlativo.

---

## 18. Actualizaciones de Navegación y UI

### Drawer lateral (AppDrawer)
Widget compartido `lib/shared/widgets/app_drawer.dart`. Estructura:
- Header con logo, nombre Cooperadora y escuela (desde ConfiguracionProvider)
- "Volver" (solo si hay pantalla anterior, con fondo gris sutil) + Divider
- "Inicio" (siempre visible)
- Divider
- Secciones según seccionesPublicas y login: Comisión Directiva (solo logueados), Proyectos, Movimientos, Cuenta Bancaria, Inventario
- Divider
- Si logueado: Mi perfil, Panel Admin (esAdmin||esAuditor), Cerrar sesión
- Si no logueado: Ingresar

Disponible en TODAS las pantallas. Parámetro `esInicio: true` en HomeScreen para ocultar "Volver".

### AppBar pantallas secundarias
Patrón estándar en todas las pantallas que no son HomeScreen:
```
[☰ Menú] | [🏠 Casita] | [Título]  [Avatar]
```
- `titleSpacing: 0` para eliminar spacing automático
- Separadores verticales `Container(width:1, height:20, color: white.withOpacity(0.3))`
- Casita con `IconButton` de 48x48 igual que hamburguesa
- Casita navega a HomeScreen con `pushAndRemoveUntil`

### Solapas con íconos
- Cuenta Bancaria: tab Cuenta Bancaria (`Icons.account_balance`) + Caja Chica (`Icons.point_of_sale`)
- Proyectos: En curso (`Icons.play_circle`) + Planificados (`Icons.pending`) + Finalizados (`Icons.check_circle`)
- TabBar: `labelColor: Colors.white`, `unselectedLabelColor: Colors.white`, `indicatorColor: Color(0xFF00BCD4)` (cyan)

### PopScope — cambios pendientes
Implementado en pantallas con edición inline. Al navegar con cambios sin guardar, muestra dialog con opciones: "Seguir editando", "Descartar cambios", "Guardar y salir".

---

## 19. Rediseño Persona-Socio-Curso (CAMBIO ESTRUCTURAL)

### Cambios en Persona
Nuevos campos: `tipoPersona` (fisica/fiscal), `fechaNacimiento` (timestamp, nullable), `razonSocial` (nullable), `cuit` (nullable), `personaContactoId` (nullable), `subtipo`, `cursoId` (nullable, solo alumnos), `hijosIds` (array, opcional, informativo).

Campo eliminado: `cargoId` — reemplazado por `Cargo.personaId` para evitar redundancia.

### Nueva entidad: Curso
Colección `cursos`. Campos: id, nombre, nivel (opcional), orden (opcional — si no existe, dropdown ordena alfabéticamente), activo. Gestionable desde panel Admin.

### Socio — modelo simplificado
Campo `personaId` reemplaza `apellidoFamilia`. Nuevo campo `numeroSocio` (correlativo único, obligatorio por ley, formato N°001). Eliminada entidad Integrante completamente.

### Cargo — relación unificada
Solo existe `Cargo.personaId`. Eliminado `Persona.cargoId` (era redundante). Para obtener el cargo de una Persona: buscar en CargoProvider donde `cargo['personaId'] == persona.id`.

### Comisión Directiva
Colección `cargos` con 11 documentos fijos ordenados por `orden`. Pantalla pública `ComisionDirectivaScreen` (solo para logueados desde el drawer). Pantalla de admin `ComisionDirectivaAdminScreen` para asignar Personas a cargos con Autocomplete.

---

## 20. Mejoras en Formularios

### Número de comprobante
Campo `nroComprobante` String nullable agregado a Ingreso y Gasto. Campo de texto opcional en formulario antes de los botones de adjuntar archivo.

### Número de cheque
Campo `nroCheque` String nullable en Ingreso, Gasto y Cuota. Widget compartido `lib/shared/widgets/numero_cheque_widget.dart` — aparece automáticamente cuando método de pago contiene "cheque", obligatorio. Aplicado en formulario de movimientos, modal de cuota de socio y pago rápido.

### Creación de Persona con acceso a la app
Toggle "Crear acceso a la app" (activo por defecto) en formulario de alta de Persona. Rol por defecto: Consultante. Restricciones por rol del que crea:
- Editor: puede asignar Consultante o Solo lectura
- Admin: puede asignar Consultante, Solo lectura, Auditor o Editor

Al guardar con acceso: crea Auth user + documento usuarios + envía email de reset de contraseña (Firebase Auth). No se guarda ni muestra contraseña.

### Navegación bidireccional Socio-Usuario
- Desde Socio → botón "Ver usuario" o "Crear acceso" según si ya tiene Usuario vinculado
- Desde Usuario → botón "Ver/editar persona" vinculada
- `UsuarioDetalleScreen`: muestra foto, datos personales, rol, estado. Admin puede editar rol. Propio usuario puede editar datos pero no su rol.

### Caja Chica — link a movimiento asociado
En historial de Caja Chica, si el movimiento tiene `gastoId` o `ingresoId` (generado automáticamente por gasto/ingreso en efectivo), muestra botón "Ver gasto/ingreso asociado" que navega a MovimientosScreen con ese movimiento expandido.


---

## 21. Módulo Informes

### Estructura de la pantalla
- Panel de filtros compartido (fondo blanco) con:
  - Selector de período: Mes | Trimestre | Año | Libre
  - Para "Año": selector de mes de cierre del ejercicio (por defecto Abril). El ejercicio anual va del 1 del mes siguiente al cierre del año anterior, al día 30 del mes de cierre del año actual.
  - Para "Libre": selectores Desde/Hasta
  - Toggle Detallado/Agrupado con íconos
  - Botón "Calcular" en verdeTeal
- TabBar con indicador cyan (0xFF00BCD4), texto e íconos blancos:
  - Balance (`Icons.table_chart`)
  - Gráficos (`Icons.bar_chart`)
  - PDF (`Icons.picture_as_pdf`)

### Vista Detallada vs Agrupada
Default por período:
- Mes → Detallado
- Trimestre → Agrupado
- Año → Agrupado
- Libre → Detallado si ≤45 días, Agrupado si >45 días

**Detallado (modelo mensual oficial ABC.gob.ar):**
- ENTRADAS: agrupadas por Rubro → Categoría con monto total
- SALIDAS: detalle de cada transacción con Fecha, N° comprobante, Descripción, Monto, agrupadas por Rubro

**Agrupado (modelo anual oficial ABC.gob.ar):**
- ENTRADAS: Rubro → Categoría → Total período
- SALIDAS: Rubro → Categoría → Total período (sin detalle de transacciones)

### Resumen al pie (ambas vistas)
- Total Entradas (a)
- Saldo ejercicio anterior (1)
- Total General (Total entradas + Saldo anterior)
- Total Salidas (b)
- Saldo próximo ejercicio (2) = Total General - Total Salidas
- En Banco (3) — debe coincidir con extracto bancario
- En Caja Chica (4) — debe coincidir con efectivo en caja

### Rubros
Colección `rubros` en Firestore con campos: activo, esPredeterminado, fechaCreacion, nombre, orden, tipo (ingreso/gasto). Las categorías se asocian a rubros mediante campo `rubroId` en cada categoría.

### Cierre de Balance
- Colección `balance_snapshots` con índice compuesto: fechaDesde ASC + fechaHasta ASC + version DESC
- Pueden cerrar balance: Editor y Admin (verificado via `ComisionService.esMiembroComisionDirectiva()`)
- Regla Firestore: `allow write: if esEditor() && estaActivo()`

### PDF
- Diseño monocromático para impresión B&N
- Paleta: negro, gris oscuro (#333), gris medio (#666), gris claro (#CCC), blanco, fondo sección (#F5F5F5)
- Sin fondos de color oscuro, sin texto blanco sobre fondo oscuro
- Negativos con paréntesis en lugar de rojo
- Espacio para firma Tesorero/a al pie
- Sin marca de agua PREVIEW

### Gráficos
- Evolución mensual (barras, fl_chart)
- Distribución por categoría (torta)
- Top categorías (barras horizontales)
- Pendiente: exportación de gráficos a PDF/Excel

### Excel
- Pendiente de implementar siguiendo formato oficial de los templates del ABC.gob.ar


---

## 22. Pendiente técnico — Revisión de código

Cuando el desarrollo esté más estable, hacer una sesión dedicada de revisión con Claude Code:
1. Revisar todos los `TODO` pendientes en el código
2. Identificar y eliminar código duplicado
3. Verificar que todos los providers tienen `dispose()` correcto
4. Revisar que no hay memory leaks en streams
5. Revisar performance general de queries a Firestore


---

## 23. Pendiente — Mejora del diseño Excel del balance

El Excel exportado funciona pero necesita mejoras de diseño:
- Formato de celdas más prolijo (anchos de columna, colores de encabezado, bordes)
- Verificar que los totales y fórmulas calculen correctamente
- Revisar presentación del resumen al pie
- Considerar agregar exportación de gráficos a PDF/Excel


---

## 24. Módulo Presupuestos de Proyecto

### Entidad PresupuestoProyecto
Colección `presupuestos_proyecto`. Presupuestos a nivel del Proyecto completo (cotizaciones globales), separados de los presupuestos de ítems individuales. Ilimitados por proyecto.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `proyectoId` | string | |
| `descripcion` | string | Opcional |
| `archivos` | array\<string\> | URLs Firebase Storage. Múltiples archivos por presupuesto |
| `usuarioId` | string | |
| `ultimaModificacionPor` | string | Nullable |
| `ultimaModificacionFecha` | timestamp | Nullable |
| `fechaCreacion` | timestamp | |

**Regla Firestore:** `allow read: if estaAutenticado(); allow write: if esEditor() && estaActivo()`

**Path Storage:** `comprobantes/presupuestos_proyecto/{proyectoId}/{presupuestoId}/{archivo}`

**UI:** Sección expandible en `proyecto_detalle_screen.dart`. Título "Presupuesto N" generado dinámicamente por posición (no almacenado). Al expandir: descripción, archivos descargables, ítems vinculados con totales, quién cargó.

### Vinculación Ítems ↔ Presupuestos
Campo `presupuestosIds` (List\<String\>) en `ItemProyecto` — un ítem puede estar incluido en múltiples presupuestos. Se selecciona mediante checkboxes en el modal de edición del ítem.

### Flujo automático Gasto → Ítems
Cuando se carga un Gasto vinculado a un Proyecto con un Presupuesto seleccionado:
1. Se guarda el gasto con `presupuestoProyectoId`
2. Todos los ítems que tienen ese presupuesto en `presupuestosIds` pasan automáticamente a estado `comprado`
3. Se guarda `estadoAnterior` y `gastoQueLoActualizó` en cada ítem para poder revertir

Si se elimina el gasto: los ítems vuelven a su `estadoAnterior` y se limpian los campos temporales.

Campo `presupuestoProyectoId` agregado a `Gasto`.

### Mejoras de navegación y UI
- Login/Registro: ancho máximo 400px centrado, mismo diseño consistente
- "Olvidaste tu contraseña" funcional: envía email real de reset con Firebase Auth
- Login/Registro tienen drawer y casita en AppBar
- Informes: tab PDF eliminada, botones "Exportar PDF" y "Exportar Excel" siempre visibles
- Toggle Detallado/Agrupado con íconos en panel de filtros compartido (fondo blanco)
- Ejercicio anual configurable por mes de cierre (default Abril)
- Rubros: colección `rubros` en Firestore, asociados a categorías para organizar el balance
- Firebase Hosting: página personalizada en `hosting/accion.html` para reset de contraseña


---

## 25. Módulo Votaciones

### Reglas institucionales
- **Quórum legal (Asamblea formal):** ceil(miembrosCD × 0.30) × 3 + ese número de socios activos
  - Ejemplo: 11 CD → ceil(3.3) = 4 → 4 × 3 = 12 socios → quórum = 16
- **Democracia directa:** piso de 15 socios activos, ideal 30% del padrón
- **Mayoría:** 2/3 de los presentes (configurable)
- **Voz consultiva:** Socios Consultantes pueden votar pero resultado se muestra separado, NO afecta resultado oficial

### Configuración (en colección `configuracion`)
Campos a agregar: `quorumPorcentajeCD` (default 30), `quorumMultiplicadorSocios` (default 3), `quorumPisoSociosDirecta` (default 15), `quorumPorcentajePadron` (default 30), `mayoriaRequerida` (default 66.67)

### Entidad: Votacion
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `titulo` | string | |
| `descripcion` | string | Opcional |
| `proyectoId` | string | Opcional — vinculada a un proyecto |
| `estado` | string | `en_curso` / `aprobada` / `rechazada` / `cerrada_sin_quorum` |
| `fechaInicio` | timestamp | |
| `fechaLimite` | timestamp | Opcional |
| `totalSociosActivos` | number | Snapshot del padrón al crear |
| `totalMiembrosCD` | number | Snapshot de CD al crear |
| `quorumRequerido` | number | Calculado al crear |
| `mayoriaRequerida` | number | Porcentaje, default 66.67 |
| `usuarioId` | string | Quién la creó |
| `fechaCreacion` | timestamp | |
| `fechaCierre` | timestamp | Nullable |

### Entidad: Voto
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `votacionId` | string | |
| `socioId` | string | Referencia al Socio — NO al Usuario (voto secreto) |
| `tipoSocio` | string | `activo` / `adherente` / `consultante` |
| `valor` | string | `a_favor` / `en_contra` / `abstencion` |
| `fecha` | timestamp | |

### Vista principal (comunidad completa)
- Resultado de todos los votos (activos + adherentes + consultantes)
- Barra de progreso visual
- Chip de estado: ✅ Aprobada / ❌ Rechazada / ⏳ En curso / 🔒 Cerrada sin quórum

### Vista de desglose (al entrar al detalle)
1. **Resultado oficial/legal** — solo socios activos, con quórum y mayoría requerida
2. **Resultado comunitario** — todos los que votaron
3. **Voz consultiva** — solo consultantes por separado

### Cálculo automático del estado
Se recalcula con cada voto nuevo:
- `en_curso` → quórum no alcanzado y fecha límite no vencida
- `aprobada` → quórum alcanzado + ≥ 2/3 a favor
- `rechazada` → quórum alcanzado + < 2/3 a favor
- `cerrada_sin_quorum` → fecha límite vencida sin quórum

### Colecciones Firestore
- `votaciones` — documentos de cada votación
- `votos` — todos los votos emitidos


---

## 26. Módulo Votaciones — Implementación

### Tipos de votación
- `presupuesto` — vota cada presupuesto de un proyecto independientemente
- `proyecto` — vota si un proyecto planificado se aprueba (pendiente de implementar)
- `general` — votación general sin objeto específico (pendiente)

### Modelo Voto actualizado
Campo `objetoId` agregado — ID del presupuesto específico que se está votando. Valores de `valor`: `a_favor` / `en_contra` / `abstencion`.

### Agrupación automática de presupuestos
Los presupuestos se agrupan visualmente por los ítems que cubren (campo `presupuestosIds` en cada ítem). El separador muestra los nombres de los ítems concatenados con " + ". Sin entidad nueva — se calcula al vuelo. Presupuestos sin ítems vinculados van al grupo "Sin ítems vinculados".

### UI de votación de presupuestos
Integrada en `proyecto_detalle_screen.dart` en la sección Presupuestos:
- Header de cada presupuesto muestra: ícono de voto (👍/👎/✋ o botón para votar), nombre, descripción, **monto siempre visible**, chip de estado, flecha expandir
- Sin votar: ícono con borde gris, interior transparente, ícono azul
- Votado a favor: fondo verde suave, borde verde, ícono 👍 relleno verde
- Votado en contra: opacity 0.6, ícono 👎 relleno rojo
- Abstención: fondo amarillo suave
- Aprobado: chip "Aprobado" amarillo inline con el título
- Comprado: chip "Comprado" verde inline con el título, ícono ✓
- Popup de confirmación antes de registrar voto con advertencia de voto definitivo
- "Me abstengo de votar todos" al final, cuenta para quórum

### Flujos automáticos de estado
1. **Votación aprobada → ítems a "presupuestos_aprobados":** cuando el estado de una votación cambia a `aprobada`, todos los ítems con ese presupuesto en `presupuestosIds` pasan a `presupuestos_aprobados`
2. **Gasto registrado → ítems y presupuesto a "comprado":** al guardar un gasto con `presupuestoProyectoId`, los ítems vinculados pasan a `comprado` y la votación del presupuesto pasa a estado `comprado`
3. **Gasto eliminado → reversión:** los ítems vuelven a `estadoAnterior` y la votación vuelve a `aprobada`

### Modo Testing
Configuración en `votacion_config_screen.dart` accesible desde Panel Admin:
- Toggle `modoTesting` — cuando activo: quórum = 1 voto, mayoría = 50%
- En modo testing el estado se recalcula dinámicamente al cargar la pantalla
- Botón "Resetear datos de prueba" (solo visible cuando `kMostrarOpcionesTestingDestructivas = true`)
  - Borra colecciones `votaciones` y `votos`
  - Revierte ítems en `presupuestos_aprobados` a su `estadoAnterior`
  - **IMPORTANTE:** cambiar `kMostrarOpcionesTestingDestructivas = false` antes de producción
- Constante en `lib/core/constants/app_constants.dart`

### Filtros en formulario de gastos
Al registrar un gasto:
- Dropdown proyectos: solo muestra proyectos con estado `en_curso`
- Dropdown presupuestos: solo muestra presupuestos con votación `aprobada`

### Configuración de votaciones (colección `configuracion`, doc `config`)
Campos: `quorumPorcentajeCD` (30), `quorumMultiplicadorSocios` (3), `quorumPisoSociosDirecta` (15), `quorumPorcentajePadron` (30), `mayoriaRequerida` (66.67), `modoTesting` (false)

### Validación socios duplicados
En `socio_repository.dart` al crear un socio, verificar que no existe otro con el mismo `personaId`. Si existe, lanzar excepción con el número de socio existente.

### Pendiente módulo votaciones
- Votación de proyectos planificados (desde proyecto_detalle_screen)
- Pantalla general VotacionesScreen con listado
- Sección "Votaciones activas" en HomeScreen


---

## 27. Actualizaciones Recientes — Votaciones, Presupuestos y Navegación

### Votación de Presupuestos — UI final
- Cada presupuesto se vota independientemente (👍/👎/✋)
- Agrupación automática por ítems coincidentes con separadores
- Header de cada presupuesto muestra: ícono de voto/estado, nombre, descripción, monto siempre visible, chip de estado, flecha expandir
- Presupuestos aprobados/comprados: muestran barra "Votación cerrada 🔒" con resultado del voto (ícono manito + texto en color)
- Presupuestos descartados (mismo grupo que uno aprobado): atenuados (opacity 0.6), ícono guión "—", barra "Votación no disponible · El Presupuesto X fue el seleccionado"
- "Me abstengo de votar todos": fondo gris suave (#F9F9F9), borde gris entero, alineado a la izquierda, subtítulo "Cuenta para el quórum"

### Chips de presupuesto en ítems
- Label "Presupuesto:" o "Presupuestos:" antes de los chips
- Chips compactos con ícono `Icons.description` + número, fondo celesteFondo
- Al presionar un chip: scrollea y expande el presupuesto correspondiente usando `GlobalKey` + `Scrollable.ensureVisible()`
- Ítems sin presupuesto: no muestran chips

### Navegación de Proyectos
- Tabs en el AppBar: En curso / Planificados / Finalizados
- Un solo `ProyectosScreen` con `DefaultTabController`
- `_ListaProyectos` como widget interno que filtra por estado
- FAB "+" solo visible para Editor/Admin

### Menú lateral (AppDrawer) — Reorganizado por rol
**Secciones públicas:** Inicio, Proyectos, Movimientos, Cuenta Bancaria, Inventario

**Para logueados:** Comisión Directiva, Votaciones

**Gestión (Editor/Admin):** Socios, Invitaciones, Nuevo ingreso, Nuevo gasto, Caja Chica

**Administración (solo Admin):** Panel de administración, Usuarios

**Auditoría (Auditor/Admin):** Log de cambios

**Siempre (logueados):** Mi perfil, Cerrar sesión

### Validaciones y correcciones
- Socios duplicados: validación en `socio_repository.dart` antes de crear
- Cuotas al día: contempla cuotas anuales (cubre 12 meses desde fechaPago)
- Filtro "Anual" en socios: muestra SOLO socios con cuota anual vigente
- Filtro "Mensual": muestra todos con estado real (mensual O anual vigente)
- Providers que requieren auth (`SocioProvider`, `CuotaProvider`, `UsuariosProvider`): usan `authStateChanges().listen()` para iniciar/detener stream según login
- Login/Registro: sin `AccionAuthWidget` en el AppBar

### Flujo de registro mejorado
- DNI obligatorio para todos los usuarios
- Teléfono y fecha de nacimiento opcionales con popup recordatorio al guardar si están vacíos
- Invitaciones con campo `esSocio` (bool) y `tipoSocio` opcional
- Al aceptar invitación con `esSocio: true`: crea automáticamente Persona + Usuario + Socio con número correlativo

### Restricciones de roles en formularios
- Proyectos en gastos: solo `en_curso`
- Presupuestos en gastos: solo con votación `aprobada`
- Votación cerrada: no muestra íconos de votación en presupuestos aprobados/comprados


---

## 28. Sistema de Cuotas Rediseñado — Pagos Libres

### Modelo anterior (eliminado)
La colección `cuotas` con períodos específicos fue reemplazada por `pagos_cuota` con montos libres.

### Nueva colección: `pagos_cuota`
Campos: `socioId`, `monto` (double), `metodoPagoId`, `fechaPago` (timestamp), `observaciones` (nullable), `ingresoId` (nullable — vincula con ingreso si se registró por ahí), `usuarioId`, `fechaCreacion`.

### Servicio de cálculo: `CuotaCalculoService`
Calcula el estado completo de cuotas on-the-fly:
1. Suma todos los pagos del socio ordenados por fecha
2. Distribuye el total pagado mes por mes desde la fecha de ingreso usando tarifas históricas
3. Cada mes queda en estado: `cubierto` / `parcial` / `sin_cubrir` / `sin_tarifa`
4. El sobrante queda como `creditoAFavor`

**Regla de tarifa histórica:** para cada mes se usa la tarifa vigente en ese momento (no la actual), buscando en `tarifas_cuota` la de mayor `vigenciaDesde` que no supere ese mes.

### Clase `CuotaEstado`
Contiene: `totalPagado`, `totalRequerido`, `deuda`, `creditoAFavor`, `estaAlDia`, `List<MesCuota> mesesCubiertos`, `List<PagoCuota> pagos`.

### UI en `socio_detalle_screen.dart`
- Resumen de deuda/crédito con botón "Registrar pago"
- Historial de pagos con fecha, monto, método y quién lo registró
- Cobertura mensual: lista de meses con ícono y estado (✅ Cubierto / ⚠️ Parcial / ❌ Sin cubrir)
- Modal de registro: monto libre (precargado con deuda actual), método de pago, fecha
- Si método es efectivo → suma automáticamente a Caja Chica

### Integración con Caja Chica
Pago de cuota en efectivo → suma automáticamente a Caja Chica con observación "Cuota socio N°XXX"

### Migración de datos
Método `migrarCuotasAPagos()` migra los pagos anteriores de `cuotas` a `pagos_cuota`. Se ejecuta una sola vez desde panel Admin. Los documentos migrados tienen campo `migradoDeCuotaId` para trazabilidad.

### Tarifas de cuota — UI en socios_screen.dart
Sección "Valor de la cuota social" arriba del resumen, con:
- Valor mensual y anual vigentes con fecha de vigencia
- Ícono de lápiz para editar (Editor/Admin) — crea nueva tarifa, no edita la existente
- Link "Ver historial" → modal con todas las tarifas históricas (Vigente/Vencida)

---

## 29. Cursos y Hijos de Socios

### Entidad Curso
Colección `cursos`. Campos: `numero` (string '1'-'6'), `turno` ('manana'/'tarde'), `nombre` (generado: '1° 1 (Mañana)'), `orden` (calculado: numero*10 + turno), `activo`.

12 documentos por defecto inicializados automáticamente. Dropdown en formulario de Persona cuando `subtipo == 'alumno'`.

### Hijos de socios
Campo `hijosIds` (array de personaIds) en Persona. Solo aparece la sección en personas que NO son alumno ni fiscal.

**Flujo de vinculación:**
1. Buscar por DNI primero
2. Si existe: mostrar datos y vincular
3. Si no existe: crear nueva Persona con subtipo 'alumno' y vincular

**Widget `_HijoTile`:** muestra nombre, apellido y curso del alumno. Botón desvincular (Editor/Admin).

---

## 30. Socios — Pantalla Rediseñada

### Una sola pantalla sin solapas
- Header con resumen: Total / Al día / En deuda / Deuda total acumulada
- Filtros: dropdown tipo de socio + dropdown estado cuota
- Barra de búsqueda por nombre, N° de socio o DNI
- Lista con estado de cuota inline (deuda en pesos y cantidad de meses)

### Sección de tarifas
Arriba del resumen de socios. Muestra mensual y anual vigentes. Editor/Admin puede actualizar (crea nueva tarifa preservando el historial).

### Reglas Firestore nuevas
```javascript
match /pagos_cuota/{doc} {
  allow read: if estaAutenticado();
  allow write: if (esAdmin() || esEditor()) && estaActivo();
}
match /tarifas_cuota/{doc} {
  allow read: if true;
  allow write: if (esAdmin() || esEditor()) && estaActivo();
}
match /tipos_cuota/{doc} {
  allow read: if true;
  allow write: if esAdmin() && estaActivo();
}
match /cursos/{doc} {
  allow read: if true;
  allow write: if esAdmin() && estaActivo();
}
```

