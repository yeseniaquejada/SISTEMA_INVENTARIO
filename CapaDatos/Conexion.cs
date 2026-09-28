using System.Data;
using CapaEntidad;
using Microsoft.Data.SqlClient;

namespace CapaDatos
{
    /// <summary>
    /// Acceso a SQL Server con ADO.NET y procedimientos almacenados.
    /// La cadena de conexión se asigna al iniciar la aplicación (Program.cs).
    /// </summary>
    public static class Conexion
    {
        public static string Cadena { get; set; } = "";

        public static SqlConnection Abrir()
        {
            var cn = new SqlConnection(Cadena);
            cn.Open();
            return cn;
        }

        /// <summary>Ejecuta un SP de consulta y convierte cada fila con <paramref name="mapear"/>.</summary>
        public static List<T> Listar<T>(string sp, Func<SqlDataReader, T> mapear, params SqlParameter[] parametros)
        {
            var lista = new List<T>();
            using var cn = Abrir();
            using var cmd = new SqlCommand(sp, cn) { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.AddRange(parametros);
            using var dr = cmd.ExecuteReader();
            while (dr.Read()) lista.Add(mapear(dr));
            return lista;
        }

        /// <summary>
        /// Ejecuta un SP de escritura que devuelve los parámetros de salida @Resultado y @Mensaje.
        /// </summary>
        public static Respuesta Ejecutar(string sp, params SqlParameter[] parametros)
        {
            try
            {
                using var cn = Abrir();
                using var cmd = new SqlCommand(sp, cn) { CommandType = CommandType.StoredProcedure };
                cmd.Parameters.AddRange(parametros);
                var resultado = cmd.Parameters.Add("@Resultado", SqlDbType.Int);
                resultado.Direction = ParameterDirection.Output;
                var mensaje = cmd.Parameters.Add("@Mensaje", SqlDbType.VarChar, 500);
                mensaje.Direction = ParameterDirection.Output;
                cmd.ExecuteNonQuery();

                int id = resultado.Value == DBNull.Value ? 0 : Convert.ToInt32(resultado.Value);
                string msg = mensaje.Value?.ToString() ?? "";
                return id > 0 ? Respuesta.Ok(id) : Respuesta.Error(msg == "" ? "No se pudo completar la operación" : msg);
            }
            catch (SqlException ex)
            {
                return Respuesta.Error("Error de base de datos: " + ex.Message);
            }
        }

        public static SqlParameter P(string nombre, object? valor) => new(nombre, valor ?? DBNull.Value);

        /// <summary>Parámetro de tipo tabla (EDetalleVenta, EReceta).</summary>
        public static SqlParameter Tabla(string nombre, string tipo, DataTable tabla) =>
            new(nombre, SqlDbType.Structured) { TypeName = tipo, Value = tabla };

        public static string Texto(this SqlDataReader dr, string col) => dr[col] == DBNull.Value ? "" : dr[col].ToString()!;
        public static int Entero(this SqlDataReader dr, string col) => Convert.ToInt32(dr[col]);
        public static decimal Decimal(this SqlDataReader dr, string col) => Convert.ToDecimal(dr[col]);
        public static bool Bool(this SqlDataReader dr, string col) => Convert.ToBoolean(dr[col]);
    }
}
