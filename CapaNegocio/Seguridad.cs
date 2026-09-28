using System.Security.Cryptography;

namespace CapaNegocio
{
    /// <summary>Hash de contraseñas con PBKDF2 (formato guardado: "salBase64.hashBase64").</summary>
    public static class Seguridad
    {
        private const int Iteraciones = 100_000;

        public static string GenerarHash(string clave)
        {
            byte[] sal = RandomNumberGenerator.GetBytes(16);
            byte[] hash = Rfc2898DeriveBytes.Pbkdf2(clave, sal, Iteraciones, HashAlgorithmName.SHA256, 32);
            return Convert.ToBase64String(sal) + "." + Convert.ToBase64String(hash);
        }

        public static bool Verificar(string clave, string guardado)
        {
            var partes = guardado.Split('.');
            if (partes.Length != 2) return false;
            byte[] sal = Convert.FromBase64String(partes[0]);
            byte[] esperado = Convert.FromBase64String(partes[1]);
            byte[] hash = Rfc2898DeriveBytes.Pbkdf2(clave, sal, Iteraciones, HashAlgorithmName.SHA256, esperado.Length);
            return CryptographicOperations.FixedTimeEquals(hash, esperado);
        }
    }
}
