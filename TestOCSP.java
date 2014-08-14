import java.io.*;
import java.net.SocketException;
import java.util.*;
import java.security.Security;
import java.security.cert.*;

public class TestOCSP {
    // generate certificate from cert strings
    private static CertificateFactory cf;

    private static Certificate makeCert(InputStream is) throws IOException, CertificateException {
        return cf.generateCertificate(is);
    }

    private static Certificate makeCert(String path) throws IOException, CertificateException {
        try(InputStream is = new FileInputStream(path)) {
            return makeCert(is);
        }
    }

    private static CertPath generateCertificatePath(Certificate trusted, Certificate issuer, Certificate target) throws CertificateException {
        return cf.generateCertPath(Arrays.asList(target, trusted));
    }

    private static Set<TrustAnchor> generateTrustAnchors(Certificate trusted) {

        // generate a trust anchor
        TrustAnchor anchor =
            new TrustAnchor((X509Certificate)trusted, null);

        return Collections.singleton(anchor);
    }

    public static void main(String args[]) throws Exception {
        cf = CertificateFactory.getInstance("X.509");
        // if you work behind proxy, configure the proxy.
        System.setProperty("http.proxyHost", "proxyhost");
        System.setProperty("http.proxyPort", "proxyport");

        Certificate trusted = makeCert(args[0]);
        Certificate issuer = makeCert(args[1]);
        Certificate target = makeCert(args[2]);

        CertPath path = generateCertificatePath(trusted, issuer, target);
        Set<TrustAnchor> anchors = generateTrustAnchors(trusted);

        PKIXParameters params = new PKIXParameters(anchors);

        // Activate certificate revocation checking
        //params.setRevocationEnabled(true);

        // Activate OCSP
        //Security.setProperty("ocsp.enable", "true");

        // Activate CRLDP
        //System.setProperty("com.sun.security.enableCRLDP", "true");

        // Ensure that the ocsp.responderURL property is not set.
        if (Security.getProperty("ocsp.responderURL") != null) {
            throw new
                Exception("The ocsp.responderURL property must not be set");
        }

        CertPathValidator validator = CertPathValidator.getInstance("PKIX");

        validator.validate(path, params);
    }
}
