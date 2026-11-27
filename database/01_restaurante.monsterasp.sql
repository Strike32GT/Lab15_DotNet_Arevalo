/*
  Inicialización para la base MSSQL ya creada en MonsterASP.
  Ejecutar dentro de db83114; no contiene CREATE DATABASE ni USE.
*/
IF OBJECT_ID('dbo.Usuarios', 'U') IS NOT NULL DROP TABLE dbo.Usuarios;
IF OBJECT_ID('dbo.Platos', 'U') IS NOT NULL DROP TABLE dbo.Platos;
IF OBJECT_ID('dbo.Categorias', 'U') IS NOT NULL DROP TABLE dbo.Categorias;
GO

CREATE TABLE dbo.Categorias
(
    CategoriaId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Categorias PRIMARY KEY,
    Nombre NVARCHAR(80) NOT NULL,
    Descripcion NVARCHAR(200) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_Categorias_Activo DEFAULT (1)
);
GO
CREATE UNIQUE INDEX UX_Categorias_Nombre ON dbo.Categorias (Nombre);
GO

CREATE TABLE dbo.Platos
(
    PlatoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Platos PRIMARY KEY,
    Nombre NVARCHAR(100) NOT NULL,
    Descripcion NVARCHAR(250) NULL,
    Precio DECIMAL(10,2) NOT NULL,
    Disponible BIT NOT NULL CONSTRAINT DF_Platos_Disponible DEFAULT (1),
    CategoriaId INT NOT NULL,
    CONSTRAINT FK_Platos_Categorias FOREIGN KEY (CategoriaId) REFERENCES dbo.Categorias (CategoriaId),
    CONSTRAINT CK_Platos_Precio CHECK (Precio > 0)
);
GO
CREATE UNIQUE INDEX UX_Platos_Categoria_Nombre ON dbo.Platos (CategoriaId, Nombre);
GO

INSERT INTO dbo.Categorias (Nombre, Descripcion, Activo) VALUES
(N'Entradas', N'Platos ligeros para comenzar la comida', 1),
(N'Platos de fondo', N'Especialidades de la casa', 1),
(N'Postres', N'Dulces preparados en el día', 1),
(N'Bebidas', N'Bebidas frías y calientes', 1);
GO
INSERT INTO dbo.Platos (Nombre, Descripcion, Precio, Disponible, CategoriaId) VALUES
(N'Ceviche clásico', N'Pescado fresco marinado en limón y ají', 28.90, 1, 1),
(N'Causa limeña', N'Papa amarilla con pollo y mayonesa', 22.50, 1, 1),
(N'Lomo saltado', N'Res salteada con cebolla, tomate y papas fritas', 39.90, 1, 2),
(N'Ají de gallina', N'Pollo deshilachado en crema de ají amarillo', 34.00, 1, 2),
(N'Arroz con mariscos', N'Arroz meloso con mariscos y culantro', 46.50, 1, 2),
(N'Arroz con leche', N'Postre tradicional con canela', 12.00, 1, 3),
(N'Crema volteada', N'Flan de leche con caramelo', 13.50, 1, 3),
(N'Chicha morada', N'Bebida de maíz morado con frutas', 8.00, 1, 4),
(N'Limonada frozen', N'Limón, azúcar y hielo frappé', 9.50, 1, 4);
GO
