# Cooperadora App — Documento de Contexto del Proyecto

> Versión 2.0 — Diseño de base de datos completo incluyendo sistema de votaciones y tipos de socios.
> Reinsertá este archivo al inicio de cada sesión de trabajo con IA.

---

## 1. Descripción General

Aplicación de gestión de **Ingresos y Gastos** para Cooperadoras escolares.
- Código abierto en GitHub — cada Cooperadora tiene su propia instancia Firebase
- Multi-usuario con roles diferenciados
- Secciones públicas configurables para transparencia comunitaria
- Sistema democrático de votaciones integrado

---

## 2. Stack Tecnológico

| Componente | Tecnología |
|---|---|
| App móvil (Android) + Web | Flutter |
| Base de datos | Firebase Firestore |
| Autenticación | Firebase Auth |
| Almacenamiento | Firebase Storage |
| Repositorio | GitHub (público) |
| IDE | VS Code + Claude Code |

---

## 3. Entorno de Desarrollo

- **SO:** Windows 11 (25H2) — Flutter 3.44.0
- **Flutter SDK:** `C:\dev\flutter\flutter`
- **Android SDK:** `C:\dev\AndroidSDK`
- **Proyecto:** `C:\dev\proyectos\cooperadora_app`
- **GitHub:** `https://github.com/cooperadoraeest4app/cooperadora_app`
- **Branch:** `main` — sin OneDrive, versionado solo con Git

---

## 4. Permisos por Rol

| Acción | Público | Solo lectura | Editor | Admin |
|---|---|---|---|---|
| Ver secciones públicas | ✓ | ✓ | ✓ | ✓ |
| Ver secciones privadas | — | ✓ | ✓ | ✓ |
| Cargar ingresos/gastos | — | — | ✓ | ✓ |
| Editar ingresos/gastos | — | — | ✓ | ✓ |
| Cargar socios/cuotas | — | — | ✓ | ✓ |
| Gestionar proyectos | — | — | ✓ | ✓ |
| Gestionar categorías | — | — | — | ✓ |
| Gestionar cargos | — | — | — | ✓ |
| Gestionar usuarios | — | — | — | ✓ |
| Configuración general | — | — | — | ✓ |
| Activar visibilidad pública | — | — | — | ✓ |
| Ver LogAcceso | — | — | — | ✓ |

---

## 5. Entidades — Versión 2.0 Completa

### Persona
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `apellido` | string | |
| `dni` | string | Identificador único |
| `telefono` | string | |
| `email` | string | Opcional |
| `fechaNacimiento` | timestamp | Opcional |
| `direccion` | string | Opcional. Abre Google Maps |
| `fotoUrl` | string | Opcional. URL Firebase Storage |
| `cargoId` | string | Opcional. Cargo institucional |
| `habilidades` | array\<string\> | Tags de oficios. Opcional |
| `activo` | boolean | |
| `fechaCreacion` | timestamp | |

### Cargo
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `orden` | number | |
| `activo` | boolean | |

**Por defecto:** Presidente, Secretaria, Tesorera, Vocal 1, Vocal 2, Vocal 3, Vocal 1 Suplente, Vocal 2 Suplente, Revisora de Cuenta, Profesora Revisora de Cuenta, Revisora de Cuenta Suplente.

### Usuario
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `personaId` | string | |
| `rol` | string | `admin` / `editor` / `solo_lectura` / `estudiante` (pendiente) |
| `socioId` | string | Opcional |
| `activo` | boolean | |
| `fechaCreacion` | timestamp | |

> Último acceso se consulta dinámicamente desde LogAcceso.
> Miembros de comisión directiva = Usuarios cuya Persona tiene `cargoId` asignado.

### Log de Acceso
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `usuarioId` | string | |
| `fecha` | timestamp | |
| `dispositivo` | string | Opcional |
| `accion` | string | `login` / `logout` / `sesion_expirada` |

> Sin IP por Ley 25.326 de Protección de Datos Personales.

### Método de Pago
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `orden` | number | |
| `activo` | boolean | |

**Por defecto:** Efectivo, Transferencia bancaria, Débito, Crédito, Cheque.

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

**Ingresos:** Cuota de socios, Donación, Subsidio, Evento, Venta, Otros ingresos.
**Gastos:** Servicios, Materiales escolares, Equipamiento, Mantenimiento, Honorarios, Eventos, Otros gastos.

### Frecuencia de Recurrencia
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `diasIntervalo` | number | Ej: 7, 15, 30 |
| `orden` | number | |
| `activo` | boolean | |

**Por defecto:** Semanal (7), Quincenal (15), Mensual (30), Bimestral (60), Trimestral (90), Anual (365).

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
| `proximaFecha` | timestamp | Opcional. Calculada automáticamente |
| `usuarioId` | string | |
| `comprobante` | string | Opcional |
| `fechaCreacion` | timestamp | |

### Gasto
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `monto` | number | |
| `moneda` | string | Por defecto `"ARS"`. Oculto en interfaz |
| `fecha` | timestamp | |
| `descripcion` | string | Opcional |
| `metodoPagoId` | string | |
| `categoriaId` | string | Solo tipo gasto |
| `proyectoId` | string | Opcional |
| `itemProyectoId` | string | Opcional |
| `recurrente` | boolean | |
| `frecuenciaId` | string | Opcional |
| `proximaFecha` | timestamp | Opcional. Calculada automáticamente |
| `usuarioId` | string | |
| `comprobante` | string | Opcional |
| `fechaCreacion` | timestamp | |

### Tipo de Socio
Basado en Decreto 4767/72 Art. 40°.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | Activo, Honorario, Adherente, Consultante |
| `tieneVoto` | boolean | Solo Activo = true |
| `tieneVozConsultiva` | boolean | Adherente y Consultante = true |
| `requiereCuota` | boolean | Activo y Adherente = true |
| `orden` | number | |
| `activo` | boolean | |

### Subtipo de Socio
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `aplicaA` | array\<string\> | Lista de tipoSocioId |
| `orden` | number | |
| `activo` | boolean | |

**Activo, Adherente, Consultante:** Padre, Madre, Familiar, Docente, Auxiliar, No docente, Directivo, Alumno, Ex-alumno, Otro.
**Honorario:** Empresa, Persona física, Organización, Otro.

### Socio
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `tipoSocioId` | string | |
| `subtipoSocioId` | string | |
| `apellidoFamilia` | string | Para Activos, Adherentes y Consultantes |
| `razonSocial` | string | Solo Honorarios empresas/organizaciones |
| `cuit` | string | Solo Honorarios empresas/organizaciones |
| `personaContactoId` | string | Para Honorarios: el delegado |
| `activo` | boolean | |
| `fechaIngreso` | timestamp | |
| `observaciones` | string | Opcional |

### Integrante
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `personaId` | string | |
| `socioId` | string | |
| `tipo` | string | `padre` / `madre` / `tutor` / `alumno` |
| `grado` | string | Solo si alumno. Opcional |

### Tipo de Cuota
**Por defecto:** Mensual, Anual.

### Tarifa de Cuota
Historial de valores por tipo. Nuevo registro al actualizar precio.

### Cuota
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `socioId` | string | |
| `tipoCuotaId` | string | |
| `tarifaId` | string | |
| `periodo` | string | MM/YYYY |
| `monto` | number | Monto efectivamente pagado |
| `metodoPagoId` | string | |
| `fechaPago` | timestamp | |
| `usuarioId` | string | |
| `comprobante` | string | Opcional |
| `observaciones` | string | Opcional |
| `fechaCreacion` | timestamp | |

### Tipo de Proyecto
**Por defecto:** Evento, Infraestructura, Viaje de Estudios, Equipamiento, Otros.
> Evento fue absorbido por Proyecto via este campo.

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
| `responsables` | array\<string\> | |
| `publico` | boolean | Por defecto true |
| `votacionId` | string | Opcional |
| `fechaCreacion` | timestamp | |

### Revisión de Presupuesto
Historial de cambios de presupuesto. Nuevo registro al modificar.

### Proveedor
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `nombre` | string | |
| `contacto` | string | Opcional |
| `telefono` | string | Opcional |
| `email` | string | Opcional |
| `cuit` | string | Opcional |
| `direccion` | string | Opcional |
| `web` | string | Opcional |
| `rubro` | string | Opcional |
| `confianza` | boolean | |
| `observaciones` | string | Opcional |
| `activo` | boolean | |
| `fechaCreacion` | timestamp | |

### Item de Proyecto
Flujo: `pendiente` → `en_gestion` → `presupuestos_aprobados` → `comprado`

### Presupuesto de Proveedor
Máximo 3 por ítem. Solo uno puede estar aprobado.

### Votación
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `titulo` | string | |
| `descripcion` | string | Opcional |
| `entidadTipo` | string | `proyecto` / `presupuesto_proveedor` / `otro` |
| `entidadId` | string | |
| `estado` | string | `abierta` / `cerrada` / `aprobada` / `rechazada` |
| `modalidad` | string | `digital` / `presencial` / `mixta` |
| `fechaInicio` | timestamp | |
| `fechaFin` | timestamp | Mismo día para presencial |
| `porcentajeAprobacion` | number | Por defecto desde Configuración |
| `quorumMinimo` | number | Por defecto desde Configuración |
| `participantes` | array\<string\> | socioId que votaron |
| `votosAfavor` | number | Solo socios Activos |
| `votosEnContra` | number | Solo socios Activos |
| `abstenciones` | number | Solo socios Activos |
| `votosConsultivosAfavor` | number | Adherentes y Consultantes |
| `votosConsultivosEnContra` | number | Adherentes y Consultantes |
| `forzadoPorAdmin` | boolean | |
| `usuarioId` | string | |
| `fechaCreacion` | timestamp | |

### Voto
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | |
| `votacionId` | string | |
| `valor` | string | `afirmativo` / `negativo` / `abstencion` |
| `tipoSocioId` | string | Se desprende del tipo de socio del votante |
| `modalidad` | string | `digital` / `presencial` |
| `fechaCreacion` | timestamp | |

> **SocioId NO se guarda** para preservar secreto del voto. Participación en array `participantes` de Votación.

### Configuración
| Campo | Tipo | Notas |
|---|---|---|
| `id` | string | Fijo: `"config"` |
| `nombreCooperadora` | string | |
| `nombreEscuela` | string | |
| `direccionEscuela` | string | Opcional |
| `telefonoContacto` | string | Opcional |
| `emailContacto` | string | Opcional |
| `logoUrl` | string | Opcional |
| `seccionesPublicas` | map | |
| `monedaDefault` | string | ARS |
| `añoLectivoActivo` | number | |
| `quorumMinimoDefault` | number | % socios activos requerido |
| `porcentajeAprobacionDefault` | number | % votos afirmativos requerido |
| `fechaActualizacion` | timestamp | |
| `usuarioId` | string | |

---

## 6. Pendientes

- **Rol Estudiante:** definir acceso y autenticación
- **Ideas futuras:** módulo pasantías, Socio Vitalicio

---

## 7. Orden de Desarrollo

1. Configurar Firebase
2. Estructura base Flutter
3. Módulo Configuración
4. Módulo Ingresos y Gastos
5. Módulo Categorías y Métodos de Pago
6. Módulo Socios y Cuotas
7. Módulo Proyectos
8. Gráficos y reportes
9. Módulo Votaciones

---

## 8. Decisiones Clave

- Firestore: sin migraciones, campos agregables en cualquier momento
- Persona como base: sin duplicación de datos personales
- Voto secreto: socioId no en Voto, participación en array de Votación
- Una instancia Firebase por Cooperadora
- Sin IP en logs por Ley 25.326
- Evento absorbido por Proyecto via TipoProyecto
- Gastos/Ingresos recurrentes via FrecuenciaRecurrencia
- Tipos de socio basados en Decreto 4767/72 Art. 40° + Consultante propio

---

*v2.0 — Base de datos completa. Próximo paso: configurar Firebase.*
