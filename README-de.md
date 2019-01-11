*In anderen Sprachen lesen: [English](README.md), [中文](README-cn.md).*

[![build status](https://travis-ci.org/IBM/FfDL.svg?branch=master)](https://travis-ci.org/IBM/FfDL)

# Fabric for Deep Learning (FfDL)

### [Latest: PyTorch 1.0 and ONNX support now in FfDL](/etc/examples/PyTorch.md)

Dieses Repository enthält die Kerndienste der *FfDL*-Plattform, welche "fiddle" ausgesprochen wird und für "Fabric for Deep Learning" steht, also eine grundfaserartige Infrastrukturlösung zum Training neuronaler Netze. Darüber hinaus bietet FfDL die folgenden Eigenschaften:
- Framework-unabhängiges und optional verteiltes Training von Deep-Learning-Modellen
- Offene Programmierschnittstellen (gRPC- und REST-APIs)
- Unterstützt On-Premise- sowie Public-Cloud-Deployments

Hier ist ein architektonischer Überblick der Plattform:

![ffdl-architecture](docs/images/ffdl-architecture.png)

Weitere Ausführungen zur Architektur finden sich im [Designdokument](design/design_docs.md). Zudem finden sich weitere Demos sowie Links zu Artikeln, Videos und verwandten Projekten [hier](https://github.com/AISphere/ffdl-community/tree/master/demos).

## Systemvoraussetzungen

* `kubectl`: Kubernetes Befehlszeilenwerkzeug (https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* `helm`: Kubernetes Paketmanager (https://helm.sh)
* `docker`: Docker, Software-Containerisierungslösung (https://www.docker.com/)
* `S3 CLI`: [AWS Befehlszeilenwerkzeug](https://aws.amazon.com/cli/), welches bei der Administration von Cloud Object Storage (COS) hilft
* Bestehender Kubernetes-Cluster (etwa [Kubeadm-DIND](https://github.com/kubernetes-sigs/kubeadm-dind-cluster#using-preconfigured-scripts)) zum lokalen Testen.
* Es ist ebenfalls möglich, [IBM Cloud Public](https://github.com/IBM/container-journey-template/blob/master/README.md) oder [IBM Cloud Private](https://github.com/IBM/deploy-ibm-cloud-private/blob/master/README.md) einzusetzen.
* Minimal werden 4GB Hauptspeicher und 3 CPUs benötigt.

## Einsatzszenarien

* Falls Sie einen schnellen Einstieg suchen, folgen Sie bitte [Kapitel 1 (Schnellstart)](#1-quick-start).
* Falls Sie FfDL bereits lauffähig aufgesetzt haben, finden Sie Anleitungen zum Training von Deep-Learning-Modellen im [FfDL Nutzerhandbuch](docs/user-guide.md).
* Weitere Details zum Training mit GPU-Beschleunigung finden Sie [hier](docs/gpu-guide.md)
* Sie können die [Adversarial Robustness Toolbox](https://github.com/IBM/adversarial-robustness-toolbox) nutzen, um Ihre Modelle gegen Adversarial Attacks zu härten - entsprechende Jupyter-Notebooks stellen wir [hier](etc/notebooks/art) zur Verfügung.
* Instruktionen, um fertig trainierte Modelle zu deployen, entnehmen Sie bitte der [Integrationsdokumentation für Seldon](https://github.com/AISphere/ffdl-community/tree/master/FfDL-Seldon)
* Integration von traditionellen Machine-Learning-Ansätzen via H2O.ai entnehmen Sie bitte der [Integrationsdokumentation für H2O](https://github.com/AISphere/ffdl-community/tree/master/FfDL-H2Oai)
* Falls Sie von FfDL auf eine GPU-fähige Public-Cloud-Lösung mit kommerziellem Support ([Watson Studio Deep Learning](https://www.ibm.com/cloud/deep-learning)) migrieren wollen, folgen Sie bitte den Anweisungen [hier](etc/converter/ffdl-wml.md).

## Inhaltsverzeichnis

1. [Schnellstart](#1-schnellstart)
  - 1.1 [Installation via Kubeadm-DIND](#11-installation-using-kubeadm-dind)
  - 1.2 [Installation via Kubernetes-Cluster](#12-installation-using-kubernetes-cluster)
2. [Testen](#2-testen)
3. [Monitoring](#3-monitoring)
4. [Entwicklung](#4-development)
5. [Clean Up](#7-clean-up)
6. [Troubleshooting](#8-troubleshooting)
7. [References](#9-references)

## 1. Schnellstart

Es gibt mehrere Installationspfade, um FfDL auf einen bestehenden Kubernetes-Cluster zu installieren. Im Folgenden sind die Schnellinstallationsschritte aufgeführt; detailliertere Schritt-für-Schritt Instruktionen finden sich im  [ausführlichen Installationshandbuch](docs/detailed-installation-guide.md).

Falls Sie die bash Befehlszeile einsetzen, können Sie die notwendigen Umgebungsvariablen wie folgt aus der Datei `env.txt` setzen und exportieren:
>  ```shell
>  source env.txt
>  export $(cut -d= -f1 env.txt)
>  ```

### 1.1 Installation via Kubeadm-DIND

Falls Sie [Kubeadm-DIND](https://github.com/kubernetes-sigs/kubeadm-dind-cluster#using-preconfigured-scripts) auf Ihrer Maschine installiert haben, nutzen Sie bitte die folgenden Befehle zur Inbetriebnahme:
``` shell
export VM_TYPE=dind
export PUBLIC_IP=localhost
export SHARED_VOLUME_STORAGE_CLASS="";
export NAMESPACE=default # If your namespace does not exist yet, please create the namespace `kubectl create namespace $NAMESPACE` before running the make commands below

make deploy-plugin
make quickstart-deploy
```

### 1.2 Installation via Kubernetes-Cluster

Um FfDL auf einem beliebigen Kubernetes-Cluster in Betrieb nehmen wollen, stellen Sie bitte sicher, dass `kubectl` auf den gewünschten Namensraum zeigt und führen Sie dann die folgenden Befehle aus:

> Hinweis: Für PUBLIC_IP verwenden Sie bitte eine öffentliche IP eines NodePorts Ihres Clusters. Für IBM Cloud können Sie eine solche mittels `ibmcloud cs workers <cluster_name>` bestimmen.

``` shell
export VM_TYPE=none
export PUBLIC_IP=<Cluster Public IP>
export NAMESPACE=default # Falls der Namensraum noch nicht existieren sollte, erstellen Sie diese bitte zunächst mit `kubectl create namespace $NAMESPACE`, bevor Sie die weiteren Befehle ausführen

# Bitte ändern Sie die Storageclass entsprechend dem ab, was auf Ihrem Cluster verfügbar ist
export SHARED_VOLUME_STORAGE_CLASS="ibmc-file-gold";

make deploy-plugin
make quickstart-deploy
```

## 2. Test

Um einen einfachen Trainingsjob als Beispiel auszuführen, dessen zugehörige Daten sich im `etc/examples`befinden, führen Sie bitte die folgenden Befehle aus: 

``` shell
make test-push-data-s3
make test-job-submit
```

## 3. Monitoring

FfDL wird mit einem Grafana-Dashboard für das Monitoring ausgeliefert. Die entsprechende URL wird angezeigt, wenn das Make-Target `deploy` ausgeführt wird.

## 4. Development

Falls Sie Entwickler sind und FfDL modifizieren möchten, finden Sie wertvolle Hinweise im [Entwicklungshandbuch](docs/developer-guide.md).

## 5. Clean Up
Falls Sie FfDL von Ihrem Cluster entfernen möchten, verwenden Sie bitte die folgenden Befehle:
```shell
helm delete $(helm list | grep ffdl | awk '{print $1}' | head -n 1)
```
(`make undeploy`, falls Sie FfDL manuell statt via Helmcharts deployt haben.)

Falls Sie den Treiber für Cloud-Object-Speicher sowie PVCs von Ihrem Cluster entfernen möchten, führen Sie die folgenden Befehle aus:
```shell
kubectl delete pvc static-volume-1
helm delete $(helm list | grep ibmcloud-object-storage-plugin | awk '{print $1}' | head -n 1)
```

Um die für Kubeadm-DIND weitergeleiteten Ports zu entfernen, nutzen Sie bitte den folgenden Befehl. Bitte beachten Sie, dass dieser alle mit `kubectl` erstellten Portweiterleitungen schließt.
```shell
kill $(lsof -i | grep kubectl | awk '{printf $2 " " }')
```

## 6. Troubleshooting

* FfDL wird derzeit nur mit Linux und macOS getestet.

* Falls `glide install` mit einem Fehler über nicht-existente Pfade fehlschlägt (z.B. "Without src, cannot continue"), stellen Sie bitte sicher, dass Ihre Dateistruktur dem standardmäßigen Layout entspricht (vgl. [Systemvoraussetzungen](#systemvoraussetzungen)).

* Bitte stellen Sie, wenn Sie bei train-Befehlen Verzeichnisse angeben, sicher, dass diese keine abschließenden Querstriche `/` haben.

* Falls Ihr Job im Status "Pending" festzustecken scheint, können Sie versuchen, den Treiber für COS-Speicher via `helm install storage-plugin --set dind=true,cloud=false` für Kubeadm-DIND oder `helm install storage-plugin` für allgemeine Kubernetes-Cluster neu aufzusetzen. Bitte prüfen Sie zudem die Zugangsdaten in der Manifest-Datei.

## 7. References

Die wissenschaftliche Literatur zu dieser Plattform findet sich in den folgenden Quellen:

* B. Bhattacharjee et al., "IBM Deep Learning Service," in IBM Journal of Research and Development, vol. 61, no. 4, pp. 10:1-10:11, July-Sept. 1 2017.   https://arxiv.org/abs/1709.05871

* Scott Boag, et al. Scalable Multi-Framework Multi-Tenant Lifecycle Management of Deep Learning Training Jobs, In Workshop on ML Systems at NIPS'17, 2017. http://learningsys.org/nips17/assets/papers/paper_29.pdf
