// Copyright 2020 The Kubeflow Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package v1

import (
	common "github.com/kubeflow/common/pkg/apis/common/v1"
	autoscalingv2beta2 "k8s.io/api/autoscaling/v2beta2"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// +resource:path=pytorchjob
//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+kubebuilder:printcolumn:name="State",type=string,JSONPath=`.status.conditions[-1:].type`
//+kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`
// +kubebuilder:subresource:scale:specpath=.spec.pytorchReplicaSpecs.Worker.replicas,statuspath=.status.replicaStatuses.Active,selectorpath=.status.labelSelector

// PyTorchJob Represents a PyTorchJob resource.
type PyTorchJob struct {
	// Standard Kubernetes type metadata.
	metav1.TypeMeta `json:",inline"`

	metav1.ObjectMeta `json:"metadata,omitempty"`

	// Specification of the desired state of the PyTorchJob.
	Spec PyTorchJobSpec `json:"spec,omitempty"`

	// Most recently observed status of the PyTorchJob.
	// Read-only (modified by the system).
	Status common.JobStatus `json:"status,omitempty"`
}

// PyTorchJobSpec is a desired state description of the PyTorchJob.
type PyTorchJobSpec struct {
	// RunPolicy encapsulates various runtime policies of the distributed training
	// job, for example how to clean up resources and how long the job can stay
	// active.
	//+kubebuilder:validation:Optional
	RunPolicy common.RunPolicy `json:"runPolicy"`

	ElasticPolicy *ElasticPolicy `json:"elasticPolicy,omitempty"`

	// A map of PyTorchReplicaType (type) to ReplicaSpec (value). Specifies the PyTorch cluster configuration.
	// For example,
	//   {
	//     "Master": PyTorchReplicaSpec,
	//     "Worker": PyTorchReplicaSpec,
	//   }
	PyTorchReplicaSpecs map[common.ReplicaType]*common.ReplicaSpec `json:"pytorchReplicaSpecs"`
}

type ElasticPolicy struct {
	// minReplicas is the lower limit for the number of replicas to which the training job
	// can scale down.  It defaults to null.
	// +optional
	MinReplicas *int32 `json:"minReplicas,omitempty" protobuf:"bytes,1,opt,name=minReplicas"`
	// upper limit for the number of pods that can be set by the autoscaler; cannot be smaller than MinReplicas, defaults to null.
	// +optional
	MaxReplicas *int32 `json:"maxReplicas,omitempty" protobuf:"bytes,2,opt,name=maxReplicas"`

	RDZVBackend *RDZVBackend `json:"rdzvBackend,omitempty" protobuf:"bytes,3,opt,name=rdzvBackend"`
	RDZVPort    *int32       `json:"rdzvPort,omitempty" protobuf:"bytes,4,opt,name=rdzvPort"`
	RDZVHost    *string      `json:"rdzvHost,omitempty" protobuf:"bytes,5,opt,name=rdzvHost"`
	RDZVID      *string      `json:"rdzvId,omitempty" protobuf:"bytes,6,opt,name=rdzvId"`
	// RDZVConf contains additional rendezvous configuration (<key1>=<value1>,<key2>=<value2>,...).
	RDZVConf []RDZVConf `json:"rdzvConf,omitempty" protobuf:"bytes,7,rep,name=rdzvConf"`
	// Start a local standalone rendezvous backend that is represented by a C10d TCP store
	// on port 29400. Useful when launching single-node, multi-worker job. If specified
	// --rdzv_backend, --rdzv_endpoint, --rdzv_id are auto-assigned; any explicitly set values
	// are ignored.
	Standalone *bool `json:"standalone,omitempty" protobuf:"bytes,8,opt,name=standalone"`
	// Number of workers per node; supported values: [auto, cpu, gpu, int].
	NProcPerNode *int32 `json:"nProcPerNode,omitempty" protobuf:"bytes,9,opt,name=nProcPerNode"`

	MaxRestarts *int32 `json:"maxRestarts,omitempty" protobuf:"bytes,10,opt,name=maxRestarts"`

	// Metrics contains the specifications which are used to calculate the
	// desired replica count (the maximum replica count across all metrics will
	// be used).  The desired replica count is calculated with multiplying the
	// ratio between the target value and the current value by the current
	// number of pods. Ergo, metrics used must decrease as the pod count is
	// increased, and vice-versa.  See the individual metric source types for
	// more information about how each type of metric must respond.
	// If not set, the HPA will not be created.
	// +optional
	Metrics []autoscalingv2beta2.MetricSpec `json:"metrics,omitempty" protobuf:"bytes,11,rep,name=metrics"`
}

type RDZVConf struct {
	Key   string `json:"key,omitempty" protobuf:"bytes,1,opt,name=key"`
	Value string `json:"value,omitempty" protobuf:"bytes,2,opt,name=value"`
}

type RDZVBackend string

const (
	// BackendC10D is the rendezvous backend type for C10d.
	BackendC10D RDZVBackend = "c10d"
	// BackendETCD is the rendezvous backend type for ETCD.
	BackendETCD RDZVBackend = "etcd"
	// BackendETCDV2 is the rendezvous backend type for ETCD v2.
	BackendETCDV2 RDZVBackend = "etcd-v2"

	// PyTorchReplicaTypeMaster is the type of Master of distributed PyTorch
	PyTorchReplicaTypeMaster common.ReplicaType = "Master"
	// PyTorchReplicaTypeWorker is the type for workers of distributed PyTorch.
	PyTorchReplicaTypeWorker common.ReplicaType = "Worker"
)

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// +resource:path=pytorchjobs
//+kubebuilder:object:root=true

// PyTorchJobList is a list of PyTorchJobs.
type PyTorchJobList struct {
	// Standard type metadata.
	metav1.TypeMeta `json:",inline"`

	// Standard list metadata.
	metav1.ListMeta `json:"metadata,omitempty"`

	// List of PyTorchJobs.
	Items []PyTorchJob `json:"items"`
}

func init() {
	SchemeBuilder.Register(&PyTorchJob{}, &PyTorchJobList{})
	SchemeBuilder.SchemeBuilder.Register(addDefaultingFuncs)
}